# karaoke — Omarchy runtime status & handover (2026-09-02)

Everything below was installed/verified over Tailscale SSH (razer-studio, user mick).
No credentials appear here or anywhere in reports — they live in `config/*.env` (chmod 600) and the
source dotfiles `.usdblog` / `.usdbeulog` / `.spotilog` at the project root.

## Installed & verified ✅
| Item | Where | Version |
|---|---|---|
| USDX AppImage | `apps/UltraStarDeluxe-linux-2026.8.1.AppImage` (+ launcher `apps/ultrastardx.sh`) | v2026.8.1 (sha256 c4d92aae…) |
| Desktop entry | `~/.local/share/applications/ultrastardx.desktop` (icon `apps/ultrastardx-icon.png`) | — |
| USDB Syncer | pipx → `~/.local/bin/usdb_syncer` | 0.25.0 |
| yt-dlp (user-managed) | pipx → `~/.local/bin/yt-dlp` | 2026.08.19 |
| ffmpeg / ffprobe | system | n9.0.1 |
| karaoke CLI | `bin/karaoke` (chmod +x) | — |
| USDX song dir | `~/.config/ultrastardx/config.ini` → `~/Projects/karaoke/songs` | — |
| Spot. creds | validated via client_credentials grant | OK |

## Protocol facts learned (for future maintenance)
- USDB animux: login = POST `index.php` `user/pass/login=Login` → PHPSESSID. Search = GET
  `index.php?link=list&interpret=..&title=..&start=N`, rows `<tr data-songid="NNN">`.
  Detail = `?link=detail&id=N`. TXT = `?link=gettxt&id=N` shows a **countdown** (`time = N;`)
  then POST back `wd=1` → txt inside `<textarea name="txt">` (HTML-escaped → unescape).
  Cover = `data/cover/<id>.jpg`. USDB txts embed `#VIDEO:v=<youtube-id>` → audio source.
- hehoe.de now serves a non-HTML payload (no longer a usable plain-HTML mirror) → not wired; primary
  matcher is live USDB only. (Revisit only if USDB ever goes down; ultrastar-es torrent packs are the
  offline alternative.)

## Tested end-to-end ✅ (2 songs in `songs/`)
```
songs/Queen/Queen - Bohemian Rhapsody/  (txt+cover+mp3, 359 s audio)
songs/Metallica/Metallica - Master of Puppets/  (txt+cover+mp3, 516 s audio)
```
`karaoke scan` → 2 ok, 0 problems. Folder layout `songs/<Artist>/<Artist - Title>/` as approved.

## To reach the weekend goal — 3 short user steps
1. **Spotify top-100**: run once on Omarchy (a browser must reach localhost on THAT machine):
   ```
   ~/Projects/karaoke/bin/karaoke auth
   ```
   It prints an authorization URL, opens the browser, waits for the callback on
   `http://127.0.0.1:18080/callback`. If Spotify answers *redirect_uri_mismatch*, add that exact URI
   in the Spotify developer dashboard for the app, then re-run. Afterwards:
   ```
   ~/Projects/karaoke/bin/karaoke top --limit 100
   ~/Projects/karaoke/bin/karaoke pull --top          # ~24 s USDB wait per song; ~100 min for 100
   ```
   (A test wave of 10 first is recommended: `karaoke top --limit 10` → `karaoke pull --top`.)
2. **Optional system installs** (need sudo password — not available over SSH):
   ```
   yay -S ultrastar-manager          # library manager (nice-to-have)
   sudo pacman -S --needed transmission-cli   # only if you want ultrastar-es torrent packs later
   ```
3. **At the TV** (first USDX run): launch from the app menu (“UltraStar Deluxe”), then in
   Options → Record assign Player 1/2 to the Scarlett 2i2 inputs, set mic boost/delay, and tune
   Microphone + A/V delay (TV Game mode) during a song.

## Audio chain reminder
Procaster → Cloudlifter CL-1 → Scarlett 2i2 (both channels; **+48V ON**) → USB (class-compliant,
PipeWire active) → HDMI → Sony AV → TV. Duet = SingStar-style dual mic on one USB device; if pitch
detection misbehaves, the two-channel split can be exposed as two mono sources (see plan).

## Layout
```
~/Projects/karaoke/
├── .usdblog .usdbeulog .spotilog   # source creds (never printed)
├── songs/<Artist>/<Artist - Title>/{txt, mp3, cover.jpg}
├── apps/   config/   reports/   bin/karaoke   .venv/
```

## UPDATE 2026-09-02 (late): weekend library built 🎤
- Spotify top-100 all-time fetched (user auth fixed: `offline_access` scope is DEPRECATED/removed by Spotify in 2026 — refresh tokens now automatic; CLI default scope = `user-top-read`). **8 of Mick's top-100 exist on USDB** (verified exhaustive): Bad Omens ×5 (Just Pretend, Dying To Love, Nowhere To Go, Limits, Specter), Sleep Token - Damocles, Magdalena Bay - Death & Romance, Motionless In White - Eternally Yours. (+2 test pulls Queen/Metallica.)
- party_builder composed 125-entry pull list: 55 curated party classics (68/76 candidates existed), 50 USDB top-downloads (250-song pool from `order=rating` + local download-count re-rank; `order=views` sort is broken/dead server-side), 20 from Mick's top-40 artists ∩ USDB catalogs (BMTH ×8, Joji, etc.).
- `karaoke pull`: **113 downloaded**, 7 duplicate-skips, 5 true misses (odd collab/duet variants: Jay-Z feat. Rihanna & Kanye - Run This Town, Bob Seger & The Silver Bullet Band - We've Got Tonite, Calvin Harris & Ellie Goulding - Miracle, Reba McEntire with Brooks & Dunn duet, Mumford & Sons - Lover Of The Light).
- Final library: **123 folders, 948 MB, `karaoke scan` = 123 ok / 0 problems**. Layout `songs/<Artist>/<Artist - Title>/` everywhere.
- Tooling additions: `karaoke auth --scope`/`--redirect` overrides; multi-attempt strict USDB matcher; party_builder at /tmp (reusable pattern).
- cld2-git + ultrastar-manager BUILT (cld2 needed `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` for CMake 4.4). cld2 installed; ultrastar-manager pkg awaits: `sudo pacman -U ~/.cache/yay/ultrastar-manager/ultrastar-manager-r*.pkg.tar.zst`

## FINAL 2026-09-03: project complete ✅ (verified by Mick)
- UltraStar-Manager installed via AUR package (sudo pacman -U ...) — works, extracts fine.
- ultrastar-cli + USDB Syncer also installed and working.
- USDX (AppImage v2026.8.1) runs, picks up the 123-song library INCLUDING per-song background videos (enrich_songs.sh video.mp4/video.jpg).
- Second profile added (.spotilogwif + config/spotify_token_wif.json 0600); 3-window union mapping done (second user 183/326, Mick 37/342).
- Review files: 260903-MickLibrary.txt (20 pullable) + the second-user review file (169 pullable) in ~/Projects/karaoke/ (also mirrored to Mac Documents/Workspaces/karaoke/). Pending Mick: tick selections + run karaoke pull.
- Reusable USDB search/mapping knowledge captured in managed skill usdb-availability-mapper (search quirks, spelling cascade, catalog paging, drift caveats).
