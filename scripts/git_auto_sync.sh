#!/bin/bash
# ClipBo Continuous GitHub Synchronization Watcher
# Supports: start | stop | status | run

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PID_FILE="$REPO_ROOT/.git/auto_sync.pid"
LOG_FILE="$REPO_ROOT/.git/auto_sync.log"
SYNC_SCRIPT="$REPO_ROOT/scripts/git_sync_now.sh"
DEBOUNCE_SECONDS=8

get_repo_signature() {
    # Generates a fast fingerprint of tracked and safe source directories
    find Sources Tests scripts Package.swift .gitignore -type f -not -name ".*" -not -path "*/.*" -exec stat -f "%m %N" {} + 2>/dev/null | sort | md5 2>/dev/null || \
    find Sources Tests scripts Package.swift .gitignore -type f -not -name ".*" -not -path "*/.*" 2>/dev/null | sort | md5 2>/dev/null
}

run_watcher() {
    echo "=================================================="
    echo "🚀 ClipBo Continuous GitHub Sync Started"
    echo "   Repository: $REPO_ROOT"
    echo "   Debounce:   ${DEBOUNCE_SECONDS}s"
    echo "   Log file:   $LOG_FILE"
    echo "=================================================="

    local last_sig=""
    last_sig=$(get_repo_signature)

    while true; do
        sleep 2
        local current_sig=""
        current_sig=$(get_repo_signature)

        if [ "$current_sig" != "$last_sig" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔍 Changes detected. Waiting ${DEBOUNCE_SECONDS}s for changes to settle..."
            
            # Debounce loop: wait until no further changes occur for DEBOUNCE_SECONDS
            local settled=false
            while [ "$settled" = false ]; do
                sleep "$DEBOUNCE_SECONDS"
                local new_sig=""
                new_sig=$(get_repo_signature)
                if [ "$new_sig" = "$current_sig" ]; then
                    settled=true
                else
                    current_sig="$new_sig"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⏳ Additional changes detected. Resetting debounce timer..."
                fi
            done

            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔄 Changes settled. Running synchronization..."
            if [ -x "$SYNC_SCRIPT" ]; then
                "$SYNC_SCRIPT"
            else
                bash "$SYNC_SCRIPT"
            fi
            
            last_sig=$(get_repo_signature)
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 👁️  Resuming continuous watch..."
        fi
    done
}

case "$1" in
    start)
        if [ -f "$PID_FILE" ]; then
            OLD_PID=$(cat "$PID_FILE" 2>/dev/null || true)
            if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
                echo "⚠️  Auto-sync is already running (PID: $OLD_PID)."
                exit 0
            else
                rm -f "$PID_FILE"
            fi
        fi

        echo "🚀 Starting ClipBo GitHub Auto-Sync in background..."
        nohup "$0" run > "$LOG_FILE" 2>&1 &
        BG_PID=$!
        echo "$BG_PID" > "$PID_FILE"
        echo "✅ Auto-sync started (PID: $BG_PID)."
        echo "📄 Logs: $LOG_FILE"
        echo "💡 Use './scripts/git_auto_sync.sh status' to monitor or './scripts/git_auto_sync.sh stop' to pause."
        ;;

    stop)
        if [ -f "$PID_FILE" ]; then
            PID=$(cat "$PID_FILE" 2>/dev/null || true)
            if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
                echo "🛑 Stopping Auto-sync (PID: $PID)..."
                kill "$PID" 2>/dev/null || true
                rm -f "$PID_FILE"
                echo "✅ Auto-sync stopped."
            else
                echo "ℹ️  Auto-sync was not actively running (stale PID file removed)."
                rm -f "$PID_FILE"
            fi
        else
            echo "ℹ️  Auto-sync is not running."
        fi
        ;;

    status)
        if [ -f "$PID_FILE" ]; then
            PID=$(cat "$PID_FILE" 2>/dev/null || true)
            if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
                echo "● Auto-sync is RUNNING (PID: $PID)"
            else
                echo "○ Auto-sync is STOPPED (stale PID)"
            fi
        else
            echo "○ Auto-sync is STOPPED"
        fi

        CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
        REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "No remote configured")
        echo "   Branch: $CURRENT_BRANCH"
        echo "   Remote: $REMOTE_URL"

        if [ -f "$LOG_FILE" ]; then
            echo ""
            echo "--- Recent Activity (last 10 lines) ---"
            tail -n 10 "$LOG_FILE"
        fi
        ;;

    run)
        run_watcher
        ;;

    *)
        echo "Usage: $0 {start|stop|status|run}"
        echo ""
        echo "Commands:"
        echo "  start   - Run the continuous sync watcher in the background"
        echo "  stop    - Stop the background watcher"
        echo "  status  - Show watcher status and recent synchronization logs"
        echo "  run     - Run the watcher in the foreground (Ctrl+C to exit)"
        exit 1
        ;;
esac
