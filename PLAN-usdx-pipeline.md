# PLAN — USDX karaoke workflow on Omarchy (Arch) — v3 (FINAL layout & structure)

> **Status:** awaiting green light. Nothing installed. Verified 2 Sept 2026.
> Target machine: **Omarchy** (`razer-studio`, Arch, reachable via Tailscale — confirmed active).
> No Docker. No usdx_scraper. No install.sh. Docs live on Mac workspace; **runtime lives in `~/Projects/karaoke` on Omarchy**.

---

## 1. Directory structure (FINAL — verified)

```
~/Projects/karaoke/                  # root — already exists on Omarchy
├── .usdblog                         # USDB animux creds (plain text) — exists, referenced by path, NEVER echoed
├── .usdbeulog                       # usdb.eu creds — exists, referenced by path, NEVER echoed
├── songs/                           # USDX song root — already created; nested layout (below)
│   └── <Artist>/                    #     e.g. songs/Iron Maiden/
│       └── <Artist - Title>/        #     e.g. songs/Iron Maiden/Iron Maiden - The Trooper/
│           ├── <Artist - Title>.txt #          song definition (any .txt works — USDX treats .txt as song def)
│           ├── <Artist - Title>.mp3 #          audio (or .ogg/.m4a/.mp4 video — referenced from the txt)
│           └── cover.jpg
├── apps/                            # USDX AppImage + UltraStar-Manager (execution)
├── config/                          # karaoke tool config; spotify.env (0600) if creds provided
├── reports/                         # karaoke pull / update reports
└── packs/                           # (optional) bulk packs via Transmission (ultrastar-es torrents)
```

**✅ Nested subfolders — VERIFIED SUPPORTED (source-level evidence, 2 Sept 2026):**
- **USDX scans recursively.** Source `src/base/USongs.pas`: `CollectDirectories(StartDir, Recursive=True)` walks every subdirectory; `FindFilesByExtension(..., '*.txt', Recursive=True)` then collects `.txt` files at any depth. Any folder tree works; the folder **containing the .txt** is the song unit.
- **Official USDX songs repo** (`UltraStar-Deluxe/songs`) uses exactly this layout: per-artist top folders → per-song subfolders `Artist - Title/` with `song.txt` + audio + cover. So `songs/<Artist>/<Artist - Title>/` is the community-standard nested form.
- **USDB Syncer can produce it natively.** Its download path is a **template** (changelog-verified): components separated by `/`, last component = file base name. Example from their changelog: `:year: / :artist: / :title: / song` → `1975/Queen/Bohemian Rhapsody/song.txt`. → We configure: **`:artist: / :title: / song`** so GUI downloads land as `Artist/Title/song.txt` — same layout as Path B.

**⚠️ One correction to the proposed layout (important):** USDX's song unit is a **folder containing the .txt + its media** — you cannot drop song files loose into the artist folder (`songs/<artist>/<song>.mp3`). The correct form is one **subfolder per song** under the artist folder, i.e. `songs/<Artist>/<Artist - Title>/…`. Same organizational goal (everything grouped by artist), plus tool compatibility.

**Config kept clean:** USDX song dir → `songs/` (one root). UltraStar-Manager library root → `songs/`. USDB Syncer target → `songs/` with template above. `karaoke pull` writes the identical layout. Packs later → `packs/` (separate root added to USDX + manager, keeping bulk torrent content out of the curated tree).

---

## 2. Credentials & accounts (handled safely)

| File/account | Purpose | Handling |
|---|---|---|
| `~/Projects/karaoke/.usdblog` | usdb.animux.de (search + txt downloads; needed by USDB Syncer **and** `karaoke pull`) | Read **only on Omarchy** at execution; import into USDB Syncer login + `config/` for pull. **Never printed/echoed.** |
| `~/Projects/karaoke/.usdbeulog` | usdb.eu (secondary txt source — new uploads post-date the stale index) | Same handling; used by `karaoke pull` as fallback source. |
| ultrastar-es.org | Forum/login **not needed** for downloads (they serve via **torrent**) | Skip login. Optional: Transmission (`pacman -S transmission-cli` or GTK) for bulk packs → `packs/`. |
| Spotify (optional) | see §5 | `config/spotify.env` chmod 600 if provided. |

No secrets will ever appear in reports, logs, or code printed in chat. Tool configs on Omarchy get restrictive perms.

---

## 3. hehoe.de staleness rule (your catch — implemented)

Confirmed: `usdb.hehoe.de` index last synced **Nov 2024** — it will not know songs added to USDB/usdb.eu/ultrastar-es after that.

Rule in `karaoke pull`:
1. **Primary matcher = USDB direct search** (login-gated, live, always current). No hehoe dependency for the normal path.
2. **hehoe = backup only**, and only when the **real song's release date ≤ Nov 2024** (we check the track's actual release year first). If the song is newer than Nov 2024 → skip hehoe entirely (no point).
3. When hehoe *is* consulted: fetch **only its header/dates line** (`Databases dates: …`) to confirm freshness — no full-site scrape, token- and resource-friendly.

---

## 4. The two commands (unchanged from v2, now with final paths)

```
karaoke pull <input> [--auto] [--limit N]     # input: Exportify CSV | txt | - (paste) | top (see §5)
  → normalize → match (USDB live; hehoe only per §3) → download txt+cover → audio via yt-dlp
  → ffmpeg format → write songs/<Artist>/<Artist - Title>/… → validate song.txt → report in reports/

karaoke update                                # USDX (GitHub tag → AppImage swap), USDB Syncer (pipx upgrade),
                                              # yt-dlp/ffmpeg (pacman), UltraStar-Manager (AUR), versions → reports/
```

USDB Syncer (GUI) and `karaoke pull` (CLI) **write the same nested layout** → interchangeable, no re-organization needed. UltraStar-Manager sees everything (recursive scan of `songs/`).

---

## 5. Weekend MVP — your "top 100 all-time"

Verified: **Stats for Spotify caps at top 50** per timeframe (all-time included). For exactly **top 100 all-time**, the Spotify Web API is the reliable route (`GET /v1/me/top/tracks?time_range=long_term`, paginated 50+50).

**Recommendation: provide the Spotify Developer client ID/secret** (as you offered) →
- stored only as `~/Projects/karaoke/config/spotify.env` (0600),
- `karaoke pull top --limit 100` fetches your true top-100 all-time and runs the normal pipeline.
- Bonus: unlocks future `karaoke pull <playlist-url>` (no web tools ever again).

If you'd rather not create the dev app: fallback = top **50** from Stats for Spotify (copy/paste). Your call — 1 for full 100, 2 for 50, or 3 = "skip Spotify, I'll hand you a list".

**Batch sizing:** we'll pull in waves during the test (`--limit 10` first, verify 2 mics + sync, then continue). Total target ≤ 100 songs. Note: hit rate depends on USDB coverage of your taste — metal/rock is well covered; anything missing lands in the report for Path A (USDB Syncer GUI) or later packs.

---

## 6. Audio chain (locked from v2)

```
Procaster → Cloudlifter CL-1 → Scarlett 2i2 (input 1)  }
Procaster → Cloudlifter CL-1 → Scarlett 2i2 (input 2)  }  single +48V button = ON (both)
              │ USB class-compliant → PipeWire → HDMI → Sony AV → 85" TV
```
- Mics: 2 channels on one USB device = SingStar dual-mic pattern; USDX P1/P2 assignment in Options → Record; PipeWire mono-split fallback if needed for clean duet pitch detection.
- Echo/hearing yourselves: **deprioritized** (as requested); USDX "Microphone Playback" + 2i2 direct monitor available later.
- Latency: XLR/USB ≈ ms; HDMI/TV processing → USDX Microphone Delay + A/V Delay; TV Game mode. Tuned during test.

---

## 7. Execution checklist (when green-lit — on Omarchy over Tailscale)

1. `karaoke update` equivalents: pacman base (yt-dlp ffmpeg fuse2 python-pipx), pipx USDB Syncer, AUR UltraStar-Manager, USDX AppImage v2026.8.1 → `apps/` + desktop entry.
2. USDB Syncer: login from `.usdblog`, download-path template `:artist: / :title: / song`, target `songs/`.
3. USDX config: song dir = `songs/`; Record devices (P1/P2); mic boost; delays.
4. UltraStar-Manager: library root = `songs/`, rescan.
5. Build `karaoke` (pull + update + top) into `~/Projects/karaoke/bin/karaoke` (no install.sh — single script, inspectable).
6. Test wave (`--limit 10` of your top songs) → verify folders + USDX scan + 2 mics + scoring → then full top-100 pull.
7. Reports in `reports/`; weekend-ready.

---

## 8. Confirmations needed (final)

1. **Spotify**: provide client ID/secret (full top-100 + playlist URLs) — or top-50 via Stats for Spotify — or skip Spotify entirely and you hand me a list?
2. **Layout**: OK with `songs/<Artist>/<Artist - Title>/…` (artist group + per-song subfolder — required by USDX format)? Confirmed above it's fully supported.
3. **Omarchy access**: execution happens on `razer-studio` over Tailscale — confirm I can run `sudo pacman`/`paru` there (or that you'll run privileged commands yourself when I prompt)?
4. Anything else to fold in?
