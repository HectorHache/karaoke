#!/usr/bin/env python3
import os
import glob
import sqlite3
import re
import json
from difflib import SequenceMatcher

PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
FILES = [
    os.path.join(PROJECT_DIR, "260903-MickLibrary.txt"),
    os.path.join(PROJECT_DIR, "260903-SecondLibrary.txt"),
]

# Locate usdb_syncer's local SQLite catalog
db_candidates = (
    glob.glob(os.path.expanduser("~/.local/share/usdb_syncer/*.db")) +
    glob.glob(os.path.expanduser("~/.config/usdb_syncer/*.db"))
)

if not db_candidates:
    print("[-] Error: Local USDB database cache not found.")
    print("    Ensure usdb_syncer has completed its catalog sync.")
    exit(1)

DB_PATH = db_candidates[0]
print(f"Connected to USDB cache: {DB_PATH}")

conn = sqlite3.connect(DB_PATH)
cursor = conn.cursor()

# Detect table name (usually 'usdb_song' or 'song')
cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
tables = [r[0] for r in cursor.fetchall()]
song_table = "usdb_song" if "usdb_song" in tables else "song"

# Detect column names
cursor.execute(f"PRAGMA table_info({song_table});")
columns = [col[1] for col in cursor.fetchall()]
id_col = "song_id" if "song_id" in columns else "id"

cursor.execute(f"SELECT {id_col}, artist, title FROM {song_table}")
catalog = cursor.fetchall()
print(f"Loaded {len(catalog)} indexed songs from local database.\n")

def normalize(s: str) -> str:
    s = s.lower().replace("’", "'").replace("`", "'")
    s = re.sub(r"\(.*?\)|\[.*?\]", "", s)
    s = re.sub(r"\b(feat|ft)\.?\b.*", "", s)
    return re.sub(r"[^a-z0-9]", "", s)

def resolve_song(req_artist: str, req_title: str):
    na = normalize(req_artist)
    nt = normalize(req_title)
    
    best_id = None
    best_score = 0.0
    best_match = None

    for sid, a, t in catalog:
        c_a = normalize(a)
        c_t = normalize(t)

        if na == c_a and nt == c_t:
            return sid, a, t

        # Weighted fuzzy score (60% title, 40% artist)
        score = (SequenceMatcher(None, na, c_a).ratio() * 0.4) + \
                (SequenceMatcher(None, nt, c_t).ratio() * 0.6)

        if score > best_score and score > 0.72:
            best_score = score
            best_id = sid
            best_match = (a, t)

    if best_id:
        return best_id, best_match[0], best_match[1]
    return None, None, None

for path in FILES:
    if not os.path.isfile(path):
        continue

    base = os.path.splitext(os.path.basename(path))[0]
    out_json = os.path.join(PROJECT_DIR, f"{base}.json")
    out_usdb_ids = os.path.join(PROJECT_DIR, f"{base}.usdb_ids")

    matched_songs = []
    unmatched = []

    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or " - " not in line:
                continue
            artist, title = line.split(" - ", 1)
            sid, db_a, db_t = resolve_song(artist, title)

            if sid:
                matched_songs.append({
                    "id": int(sid),
                    "artist": db_a,
                    "title": db_t
                })
            else:
                unmatched.append(f"{artist} - {title}")

    # Output strict schema JSON: {"songs": [{"id": ...}, ...]}
    payload = {"songs": matched_songs}
    with open(out_json, "w", encoding="utf-8") as jf:
        json.dump(payload, jf, indent=2, ensure_ascii=False)

    # Output native .usdb_ids format supported by usdb_id_file.py
    with open(out_usdb_ids, "w", encoding="utf-8") as uf:
        uf.write("\n".join(str(s["id"]) for s in matched_songs) + "\n")

    print(f"=== {base} ===")
    print(f"  Matched   : {len(matched_songs)}")
    print(f"  Unmatched : {len(unmatched)}")
    print(f"  Wrote JSON: {os.path.basename(out_json)}")
    print(f"  Wrote IDs : {os.path.basename(out_usdb_ids)}")

    if unmatched:
        print("  Missing on USDB:")
        for missing in unmatched[:6]:
            print(f"    [-] {missing}")
        if len(unmatched) > 6:
            print(f"    ... and {len(unmatched) - 6} more.")
    print("-" * 50 + "\n")