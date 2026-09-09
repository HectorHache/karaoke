#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGS_DIR="${SCRIPT_DIR}/logs"
mkdir -p "$LOGS_DIR"

DRY_RUN=0
SONGS_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run|-d)
            DRY_RUN=1
            shift
            ;;
        *)
            SONGS_DIR="$1"
            shift
            ;;
    esac
done

if [ -z "$SONGS_DIR" ]; then
    if [ -d "$SCRIPT_DIR/songs" ]; then
        SONGS_DIR="$SCRIPT_DIR/songs"
    elif [ -d "$PWD/songs" ]; then
        SONGS_DIR="$PWD/songs"
    else
        SONGS_DIR="$HOME/Projects/karaoke/songs"
    fi
fi

if [ ! -d "$SONGS_DIR" ]; then
    echo "[-] Error: Directory '$SONGS_DIR' does not exist."
    exit 1
fi

START_DATE=$(date +"%y%m%d")
START_TIME=$(date +"%H%M%S")
LIVE_LOG="${LOGS_DIR}/${START_DATE}-${START_TIME}-running.log"

TOTAL_SCANNED=0
TOTAL_RENAMED=0
TOTAL_FOUND=0
TOTAL_NOT_FOUND=0
TOTAL_SKIPPED=0

cleanup_interrupted() {
    echo "" >> "$LIVE_LOG"
    echo "[!] Run interrupted by user at $(date +'%Y-%m-%d %H:%M:%S %Z')" >> "$LIVE_LOG"
    mv "$LIVE_LOG" "${LOGS_DIR}/${START_DATE}-${START_TIME}-${TOTAL_FOUND}-${TOTAL_NOT_FOUND}-interrupted.log" 2>/dev/null || true
    echo -e "\n[!] Process stopped. Partial log saved to logs/."
    exit 1
}
trap cleanup_interrupted INT TERM

{
    echo "================================================================================"
    echo "ULTRASTAR MEDIA ENRICHMENT & RENAME LOG"
    echo "Started       : $(date +'%Y-%m-%d %H:%M:%S %Z')"
    echo "Execution Dir : $SCRIPT_DIR"
    echo "Log Directory : $LOGS_DIR"
    echo "Target Path   : $SONGS_DIR"
    echo "Mode          : $( [ "$DRY_RUN" -eq 1 ] && echo "DRY RUN (Preview Only)" || echo "LIVE ENRICHMENT & RENAME" )"
    echo "================================================================================"
    echo ""
} > "$LIVE_LOG"

echo "Active root : $SCRIPT_DIR"
echo "Target path : $SONGS_DIR"
echo "Live log    : logs/$(basename "$LIVE_LOG")"
echo "Mode        : $( [ "$DRY_RUN" -eq 1 ] && echo "DRY RUN" || echo "LIVE MIGRATION & DOWNLOADS" )"
echo "--------------------------------------------------------------------------------"

while IFS= read -r -d '' txt_file; do
    dir="$(dirname "$txt_file")"
    TOTAL_SCANNED=$((TOTAL_SCANNED + 1))

    artist=$(sed '1s/^\xef\xbb\xbf//' "$txt_file" | awk -F: 'tolower($1) ~ /^#artist/ {gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", $2); print $2; exit}')
    title=$(sed '1s/^\xef\xbb\xbf//' "$txt_file" | awk -F: 'tolower($1) ~ /^#title/ {gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", $2); print $2; exit}')

    if [ -z "$artist" ] || [ -z "$title" ]; then
        echo "[-] [Skip] $(basename "$dir"): Missing #ARTIST or #TITLE tag."
        echo "[SKIP] $(basename "$dir"): Malformed or missing header tags" >> "$LIVE_LOG"
        TOTAL_SKIPPED=$((TOTAL_SKIPPED + 1))
        continue
    fi

    clean_artist=$(echo "$artist" | tr -d '/\\:?*\"<>|')
    clean_title=$(echo "$title" | tr -d '/\\:?*\"<>|')
    target_video_name="${clean_artist} - ${clean_title}.mp4"
    target_video_path="$dir/$target_video_name"

    # 1. Audit and rename old video.mp4 files if present
    existing_generic="$dir/video.mp4"
    if [ -f "$existing_generic" ] && [ ! -f "$target_video_path" ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
            echo "[Dry Run] Would rename: video.mp4 -> $target_video_name"
        else
            mv "$existing_generic" "$target_video_path"
            if grep -qi '^[[:space:]]*#VIDEO:' "$txt_file"; then
                sed -i "s|^[[:space:]]*#VIDEO:.*|#VIDEO:${target_video_name}|I" "$txt_file"
            elif grep -qi '^[[:space:]]*#MP3:' "$txt_file"; then
                sed -i "/^[[:space:]]*#MP3:/a #VIDEO:${target_video_name}" "$txt_file"
            else
                sed -i "1i #VIDEO:${target_video_name}" "$txt_file"
            fi
            echo "[Renamed] video.mp4 -> $target_video_name"
            echo "[RENAME] $artist - $title: video.mp4 -> $target_video_name" >> "$LIVE_LOG"
            TOTAL_RENAMED=$((TOTAL_RENAMED + 1))
        fi
    elif [ -f "$target_video_path" ]; then
        if grep -qi '^[[:space:]]*#VIDEO:video.mp4' "$txt_file"; then
            if [ "$DRY_RUN" -eq 0 ]; then
                sed -i "s|^[[:space:]]*#VIDEO:.*|#VIDEO:${target_video_name}|I" "$txt_file"
            fi
        fi
    fi

    # 2. Check for missing media
    video_found=$(find "$dir" -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.webm" -o -iname "*.avi" \) -print -quit)
    if [ -z "$video_found" ]; then
        needs_video=1
    else
        needs_video=0
    fi

    cover_found=$(find "$dir" -maxdepth 1 -type f \( -iname "*cover*.jpg" -o -iname "*cover*.png" -o -iname "*folder*.jpg" \) -print -quit)
    if [ -z "$cover_found" ]; then
        needs_cover=1
    else
        needs_cover=0
    fi

    if [ "$needs_video" -eq 0 ] && [ "$needs_cover" -eq 0 ]; then
        continue
    fi

    echo ""
    echo "================================================================================"
    echo "[$TOTAL_SCANNED] Enrichment Needed: $artist - $title"
    needs_str=""
    if [ "$needs_video" -eq 1 ]; then needs_str+="[Video] "; fi
    if [ "$needs_cover" -eq 1 ]; then needs_str+="[Cover] "; fi
    echo "    Needs   : $needs_str"

    query="${artist} - ${title} official music video"
    echo -n "    Probing : '$query' ... "

    yt_meta=$(yt-dlp "ytsearch1:$query" \
        --remote-components ejs:github \
        --no-warnings \
        --print "%(title)s###%(duration_string)s###%(id)s" 2>/dev/null)

    if [ -z "$yt_meta" ]; then
        echo "[FAILED / NO MATCH]"
        TOTAL_NOT_FOUND=$((TOTAL_NOT_FOUND + 1))
        {
            echo "[NO MATCH] $artist - $title"
            echo "    Query: \"$query\""
            echo ""
        } >> "$LIVE_LOG"
        continue
    fi

    yt_title=$(echo "$yt_meta" | awk -F'###' '{print $1}')
    yt_dur=$(echo "$yt_meta" | awk -F'###' '{print $2}')
    yt_id=$(echo "$yt_meta" | awk -F'###' '{print $3}')
    yt_url="https://youtu.be/$yt_id"

    echo "Match found!"
    echo "    Video   : $yt_title ($yt_dur)"
    echo "    URL     : $yt_url"

    TOTAL_FOUND=$((TOTAL_FOUND + 1))

    {
        echo "[MATCH #$TOTAL_FOUND] $artist - $title"
        echo "    Title : $yt_title"
        echo "    Dur   : $yt_dur"
        echo "    URL   : $yt_url"
        echo "    Target: $target_video_name"
    } >> "$LIVE_LOG"

    if [ "$DRY_RUN" -eq 1 ]; then
        echo "    [Dry Run] Skipping download."
        continue
    fi

    if [ "$needs_video" -eq 1 ]; then
        echo "    --> Downloading video: $target_video_name"
        yt-dlp "$yt_url" \
            --remote-components ejs:github \
            --format "bestvideo[height<=720]+bestaudio/best[height<=720]/best" \
            --merge-output-format mp4 \
            --write-thumbnail \
            --convert-thumbnails jpg \
            --output "$dir/${clean_artist} - ${clean_title}.%(ext)s" \
            --no-playlist \
            --no-warnings \
            --progress

        if grep -qi '^[[:space:]]*#VIDEO:' "$txt_file"; then
            sed -i "s|^[[:space:]]*#VIDEO:.*|#VIDEO:${target_video_name}|I" "$txt_file"
        elif grep -qi '^[[:space:]]*#MP3:' "$txt_file"; then
            sed -i "/^[[:space:]]*#MP3:/a #VIDEO:${target_video_name}" "$txt_file"
        else
            sed -i "1i #VIDEO:${target_video_name}" "$txt_file"
        fi
        echo "    --> Header updated: #VIDEO:${target_video_name}"
    fi

    if [ "$needs_cover" -eq 1 ]; then
        echo "    --> Generating 1:1 cover..."
        thumb_file=$(find "$dir" -maxdepth 1 \( -name "${clean_artist} - ${clean_title}.jpg" -o -name "${clean_artist} - ${clean_title}.webp" \) -print -quit)

        if [ -z "$thumb_file" ]; then
            yt-dlp "$yt_url" \
                --remote-components ejs:github \
                --skip-download \
                --write-thumbnail \
                --convert-thumbnails jpg \
                --output "$dir/temp_thumb" \
                --no-playlist \
                --quiet

            thumb_file=$(find "$dir" -maxdepth 1 -name "temp_thumb.jpg" -print -quit)
        fi

        if [ -n "$thumb_file" ]; then
            ffmpeg -y -v error -i "$thumb_file" -vf "crop='min(iw,ih)':'min(iw,ih)'" "$dir/cover.jpg"
            rm -f "$thumb_file"
            echo "    --> Saved cover.jpg"
        fi

        if ! grep -qi '^[[:space:]]*#COVER:' "$txt_file"; then
            if grep -qi '^[[:space:]]*#VIDEO:' "$txt_file"; then
                sed -i '/^[[:space:]]*#VIDEO:/a #COVER:cover.jpg' "$txt_file"
            else
                sed -i '1i #COVER:cover.jpg' "$txt_file"
            fi
            echo "    --> Header injected: #COVER:cover.jpg"
        fi
    fi

    echo "    [✓] Done processing $artist - $title"

done < <(find "$SONGS_DIR" -type f -iname "*.txt" -print0 | sort -z)

{
    echo ""
    echo "================================================================================"
    echo "FINAL SUMMARY"
    echo "Finished at   : $(date +'%Y-%m-%d %H:%M:%S %Z')"
    echo "Total Scanned : $TOTAL_SCANNED"
    echo "Renamed (Old) : $TOTAL_RENAMED"
    echo "Matches Found : $TOTAL_FOUND"
    echo "Unmatched     : $TOTAL_NOT_FOUND"
    echo "Skipped (Bad) : $TOTAL_SKIPPED"
    echo "================================================================================"
} >> "$LIVE_LOG"

FINAL_LOG="${LOGS_DIR}/${START_DATE}-${START_TIME}-${TOTAL_FOUND}-${TOTAL_NOT_FOUND}.log"
mv "$LIVE_LOG" "$FINAL_LOG"
trap - INT TERM

echo ""
echo "================================================================================"
echo "Run Finished!"
echo "Total Scanned : $TOTAL_SCANNED"
echo "Files Renamed : $TOTAL_RENAMED"
echo "New Downloads : $TOTAL_FOUND"
echo "Log file      : logs/$(basename "$FINAL_LOG")"
echo "================================================================================"