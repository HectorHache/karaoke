#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SONGS_DIR="$PROJECT_DIR/songs"
LOGS_DIR="$PROJECT_DIR/logs"
mkdir -p "$SONGS_DIR" "$LOGS_DIR"

MICK_LIST="$PROJECT_DIR/260903-MickLibrary"
SECOND_LIST="$PROJECT_DIR/260903-SecondLibrary"

[ -f "${MICK_LIST}.txt" ] && MICK_LIST="${MICK_LIST}.txt"
[ -f "${SECOND_LIST}.txt" ] && SECOND_LIST="${SECOND_LIST}.txt"

MERGED_LIST="$LOGS_DIR/batch_queue.txt"
rm -f "$MERGED_LIST"

echo "Aggregating song request files..."
for list_file in "$MICK_LIST" "$SECOND_LIST"; do
    if [ -f "$list_file" ]; then
        echo " [+] Loaded: $(basename "$list_file") ($(wc -l < "$list_file") lines)"
        sed -e 's/\r$//' -e '/^[[:space:]]*$/d' -e 's/^[[:space:]]*//;s/[[:space:]]*$//' "$list_file" >> "$MERGED_LIST"
    else
        echo " [!] Warning: File not found: $list_file"
    fi
done

TOTAL_SONGS=$(wc -l < "$MERGED_LIST" 2>/dev/null || echo 0)
if [ "$TOTAL_SONGS" -eq 0 ]; then
    echo "[-] No songs found to process."
    exit 1
fi

echo "--------------------------------------------------------------------------------"
echo "Aggregated $TOTAL_SONGS tracks to: $MERGED_LIST"
echo "Target directory : $SONGS_DIR"
echo "Launching USDB Syncer..."
echo "--------------------------------------------------------------------------------"

PIPX_PYTHON="$HOME/.local/share/pipx/venvs/usdb-syncer/bin/python"
if [ ! -f "$PIPX_PYTHON" ]; then
    PIPX_PYTHON="$(which python3)"
fi

export QT_QPA_PLATFORM="wayland;xcb"
export QT_MEDIA_BACKEND="null"

"$PIPX_PYTHON" "$PROJECT_DIR/launch_syncer.py" --log-level DEBUG --songpath "$SONGS_DIR"