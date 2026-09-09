python3 -c '
import json, glob

for path in glob.glob("260903-*.txt"):
    songs = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or " - " not in line:
                continue
            artist, title = line.split(" - ", 1)
            songs.append({"artist": artist.strip(), "title": title.strip()})
    out_name = path.rsplit(".", 1)[0] + ".json"
    with open(out_name, "w", encoding="utf-8") as out:
        json.dump(songs, out, indent=2, ensure_ascii=False)
    print(f"Generated {out_name} ({len(songs)} tracks)")
'