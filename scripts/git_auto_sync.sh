#!/bin/bash
# ClipBo Continuous GitHub Synchronization Watcher
# Supports: start | stop | status | run

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PID_FILE="$REPO_ROOT/.git/auto_sync.pid"
LOG_FILE="$REPO_ROOT/.git/auto_sync.log"
SYNC_SCRIPT="$REPO_ROOT/scripts/git_sync_now.sh"
DEBOUNCE_SECONDS=6

get_status_hash() {
    # Returns md5 hash of porcelain status
    git status --porcelain 2>/dev/null | md5
}

is_working_tree_dirty() {
    [ -n "$(git status --porcelain 2>/dev/null)" ]
}

run_watcher() {
    echo "=================================================="
    echo "🚀 ClipBo Continuous GitHub Sync Started"
    echo "   Repository: $REPO_ROOT"
    echo "   Debounce:   ${DEBOUNCE_SECONDS}s"
    echo "   Log file:   $LOG_FILE"
    echo "=================================================="

    while true; do
        if is_working_tree_dirty; then
            local start_hash
            start_hash=$(get_status_hash)
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔍 Uncommitted changes detected. Debouncing ${DEBOUNCE_SECONDS}s..."

            local settled=false
            while [ "$settled" = false ]; do
                sleep "$DEBOUNCE_SECONDS"
                local new_hash
                new_hash=$(get_status_hash)
                if [ "$new_hash" = "$start_hash" ]; then
                    settled=true
                else
                    start_hash="$new_hash"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⏳ Active edits continuing. Resetting debounce timer..."
                fi
            done

            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔄 Changes settled. Running synchronization..."
            if [ -x "$SYNC_SCRIPT" ]; then
                "$SYNC_SCRIPT"
            else
                bash "$SYNC_SCRIPT"
            fi
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 👁️  Continuous watch active."
        fi
        sleep 2
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
            echo "--- Recent Activity (last 15 lines) ---"
            tail -n 15 "$LOG_FILE"
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
