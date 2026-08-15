#!/bin/bash
# ClipBo One-Shot Safe Git Synchronization Script
set -e

# Change to repository root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if [ ! -d ".git" ]; then
    echo "❌ Error: Not a git repository ($REPO_ROOT)."
    exit 1
fi

# 1. Secret Scanning Pre-Check
# Scan unstaged and untracked files for suspicious private keys, tokens, or credentials
SUSPICIOUS_FILES=$(git status --porcelain | awk '{print $2}' | grep -E '\.(pem|key|p12|p8|env|credentials|secret)$|id_rsa|id_ed25519' || true)
if [ -n "$SUSPICIOUS_FILES" ]; then
    echo "⚠️ Potential secret detected in files:"
    echo "$SUSPICIOUS_FILES"
    echo "❌ Potential secret detected. Automatic GitHub push paused."
    exit 1
fi

# Check for staged or working-tree high-entropy API key patterns
SECRET_MATCHES=$(git grep -I -E "(AKIA[0-9A-Z]{16}|ghp_[0-9a-zA-Z]{36}|sk_live_[0-9a-zA-Z]{24}|AIzaSy[0-9a-zA-Z_-]{33})" -- ':!scripts/' ':!.git/' 2>/dev/null || true)
if [ -n "$SECRET_MATCHES" ]; then
    echo "⚠️ Potential secret key pattern detected in repository code:"
    echo "$SECRET_MATCHES"
    echo "❌ Potential secret detected. Automatic GitHub push paused."
    exit 1
fi

# 2. Stage safe files
git add .gitignore Package.swift Sources Tests scripts 2>/dev/null || git add -A

# 3. Check if there are staged changes
if git diff --cached --quiet; then
    # Check if there are unpushed commits
    REMOTE_EXISTS=$(git remote get-url origin 2>/dev/null || true)
    if [ -n "$REMOTE_EXISTS" ]; then
        CURRENT_BRANCH=$(git branch --show-current)
        UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)
        if [ -n "$UPSTREAM" ]; then
            UNPUSHED=$(git log "$UPSTREAM..HEAD" --oneline 2>/dev/null || true)
            if [ -n "$UNPUSHED" ]; then
                echo "📤 Pushing pending local commits to GitHub ($CURRENT_BRANCH)..."
                if git push; then
                    echo "✅ GitHub sync complete."
                else
                    echo "⚠️ Local commits exist, but GitHub push failed. Please check network/credentials."
                fi
                exit 0
            fi
        fi
    fi
    echo "✨ Everything up to date. No new changes to sync."
    exit 0
fi

# 4. Generate intelligent contextual commit message based on staged diff
STAGED_FILES=$(git diff --cached --name-only)

generate_commit_message() {
    local files="$1"
    local area=""
    local detail=""

    if echo "$files" | grep -q "SelectionModifierCaptureManager\|SelectionCapture"; then
        area="Quick Capture"
        detail="Command + Selection background capture & modifiers"
    elif echo "$files" | grep -q "ClipDisplayLimits"; then
        area="Display Limits"
        detail="Centralize 30 All / 20 per-category result limits"
    elif echo "$files" | grep -q "QuickOverlay"; then
        area="Quick Overlay"
        detail="Keyboard arrow navigation & category focus"
    elif echo "$files" | grep -q "MenuBar"; then
        area="Menu Bar"
        detail="Dynamic category navigation & panel interactions"
    elif echo "$files" | grep -q "Settings"; then
        area="Settings"
        detail="Shortcuts, preferences & diagnostics updates"
    elif echo "$files" | grep -q "Tests"; then
        area="Tests"
        detail="Update automated QA test suites"
    elif echo "$files" | grep -q "scripts/"; then
        area="Sync"
        detail="Configure continuous GitHub sync workflow"
    else
        area="Core"
        detail="ClipBo application updates"
    fi

    echo "$area: $detail"
}

COMMIT_MSG=$(generate_commit_message "$STAGED_FILES")
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# 5. Create Git commit
echo "📝 Creating commit: $COMMIT_MSG..."
git commit -m "$COMMIT_MSG" -m "Automated synchronization checkpoint at $TIMESTAMP"

COMMIT_HASH=$(git rev-parse --short HEAD)
echo "✅ Local checkpoint created successfully ($COMMIT_HASH)."

# 6. Push to GitHub if remote is configured
REMOTE_URL=$(git remote get-url origin 2>/dev/null || true)
CURRENT_BRANCH=$(git branch --show-current)

if [ -z "$REMOTE_URL" ]; then
    echo "ℹ️  Note: No GitHub remote 'origin' configured yet. Commit $COMMIT_HASH is safely saved locally."
    echo "👉 To connect to GitHub: git remote add origin <your-github-repo-url> && git push -u origin $CURRENT_BRANCH"
    exit 0
fi

echo "🚀 Pushing $CURRENT_BRANCH to GitHub ($REMOTE_URL)..."
if git push -u origin "$CURRENT_BRANCH"; then
    echo "✅ Successfully pushed checkpoint $COMMIT_HASH to GitHub ($CURRENT_BRANCH)."
else
    echo "⚠️ Local checkpoint $COMMIT_HASH created successfully, but GitHub push failed."
    echo "⚠️ Check your network connection, remote repository permissions, or GitHub credentials."
    echo "⚠️ The commit remains safe locally and will be pushed on next sync."
fi
