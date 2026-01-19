#!/bin/bash
# Bitwarden CLI helper script for DMS plugin
# Usage: bw-helper.sh <command> [args...]

set -e

BW_CLI="${BW_CLI:-bw}"

# Require XDG_RUNTIME_DIR - do not fall back to /tmp for security
if [ -z "$XDG_RUNTIME_DIR" ]; then
    echo '{"error": "XDG_RUNTIME_DIR not set. Cannot securely store session token."}'
    exit 1
fi
SESSION_FILE="$XDG_RUNTIME_DIR/bw-session"

# Check if bw is available
check_bw() {
    if ! command -v "$BW_CLI" &> /dev/null; then
        # Try common locations
        for path in ~/.local/bin/bw /usr/local/bin/bw /usr/bin/bw; do
            if [ -x "$path" ]; then
                BW_CLI="$path"
                return 0
            fi
        done
        echo '{"error": "Bitwarden CLI not found. Install with: npm install -g @bitwarden/cli"}'
        exit 1
    fi
}

# Get or create session
get_session() {
    if [ -f "$SESSION_FILE" ]; then
        cat "$SESSION_FILE"
    else
        echo ""
    fi
}

# Save session
save_session() {
    echo "$1" > "$SESSION_FILE"
    chmod 600 "$SESSION_FILE"
}

# Check login/unlock status
status() {
    check_bw
    local session=$(get_session)
    local status_output
    
    # If we have a session, test if it's valid by trying a simple command
    if [ -n "$session" ]; then
        # Try to list folders (lightweight) to verify session is valid
        if "$BW_CLI" list folders --session "$session" >/dev/null 2>&1; then
            echo '{"status":"unlocked"}'
            return 0
        fi
    fi
    
    # Fall back to bw status
    status_output=$("$BW_CLI" status 2>/dev/null || echo '{"status":"error"}')
    echo "$status_output"
}

# List all items (cached for performance)
list_items() {
    check_bw
    local session=$(get_session)
    
    if [ -z "$session" ]; then
        echo '{"error": "vault_locked", "message": "Vault is locked. Please unlock first."}'
        return 1
    fi
    
    # Get items with session
    "$BW_CLI" list items --session "$session" 2>/dev/null || echo '{"error": "list_failed"}'
}

# Search items
search_items() {
    check_bw
    local query="$1"
    local session=$(get_session)
    
    if [ -z "$session" ]; then
        echo '{"error": "vault_locked", "message": "Vault is locked. Please unlock first."}'
        return 1
    fi
    
    "$BW_CLI" list items --search "$query" --session "$session" 2>/dev/null || echo '[]'
}

# Get password for an item
get_password() {
    check_bw
    local item_id="$1"
    local session=$(get_session)
    
    if [ -z "$session" ]; then
        echo ""
        return 1
    fi
    
    "$BW_CLI" get password "$item_id" --session "$session" 2>/dev/null || echo ""
}

# Get username for an item
get_username() {
    check_bw
    local item_id="$1"
    local session=$(get_session)
    
    if [ -z "$session" ]; then
        echo ""
        return 1
    fi
    
    "$BW_CLI" get username "$item_id" --session "$session" 2>/dev/null || echo ""
}

# Get TOTP for an item
get_totp() {
    check_bw
    local item_id="$1"
    local session=$(get_session)
    
    if [ -z "$session" ]; then
        echo ""
        return 1
    fi
    
    "$BW_CLI" get totp "$item_id" --session "$session" 2>/dev/null || echo ""
}

# Get card number
get_card() {
    check_bw
    local item_id="$1"
    local session=$(get_session)
    
    if [ -z "$session" ]; then
        echo ""
        return 1
    fi
    
    local item=$("$BW_CLI" get item "$item_id" --session "$session" 2>/dev/null)
    echo "$item" | jq -r '.card.number // empty' 2>/dev/null || echo ""
}

# Get notes
get_notes() {
    check_bw
    local item_id="$1"
    local session=$(get_session)
    
    if [ -z "$session" ]; then
        echo ""
        return 1
    fi
    
    "$BW_CLI" get notes "$item_id" --session "$session" 2>/dev/null || echo ""
}

# Unlock vault - if session provided as arg, save it; otherwise read password from stdin
unlock() {
    check_bw
    
    # If a session token is provided directly, just save it
    if [ -n "${2:-}" ]; then
        save_session "$2"
        echo '{"success": true, "message": "Session saved"}'
        return 0
    fi
    
    local password
    read -r password
    
    local session
    session=$("$BW_CLI" unlock --raw "$password" 2>/dev/null)
    
    if [ -n "$session" ]; then
        save_session "$session"
        echo '{"success": true, "message": "Vault unlocked"}'
    else
        echo '{"success": false, "error": "unlock_failed", "message": "Failed to unlock vault"}'
    fi
}

# Lock vault
lock() {
    check_bw
    "$BW_CLI" lock 2>/dev/null
    rm -f "$SESSION_FILE"
    rm -f "$XDG_RUNTIME_DIR/bw-items-cache.json"
    echo '{"success": true, "message": "Vault locked"}'
}

# Sync vault
sync() {
    check_bw
    local session=$(get_session)
    
    if [ -z "$session" ]; then
        echo '{"error": "vault_locked"}'
        return 1
    fi
    
    "$BW_CLI" sync --session "$session" 2>/dev/null && echo '{"success": true}' || echo '{"success": false}'
}

# Main command dispatcher
case "${1:-}" in
    status)
        status
        ;;
    list)
        list_items
        ;;
    search)
        search_items "$2"
        ;;
    password)
        get_password "$2"
        ;;
    username)
        get_username "$2"
        ;;
    totp)
        get_totp "$2"
        ;;
    card)
        get_card "$2"
        ;;
    notes)
        get_notes "$2"
        ;;
    unlock)
        unlock "$@"
        ;;
    save-session)
        # Save session token directly: bw-helper.sh save-session <token>
        if [ -n "$2" ]; then
            save_session "$2"
            echo '{"success": true, "message": "Session saved"}'
        else
            echo '{"error": "no_session", "message": "Usage: bw-helper.sh save-session <session-token>"}'
        fi
        ;;
    lock)
        lock
        ;;
    sync)
        sync
        ;;
    *)
        echo '{"error": "unknown_command", "usage": "bw-helper.sh <status|list|search|password|username|totp|card|notes|unlock|lock|sync> [args]"}'
        exit 1
        ;;
esac
