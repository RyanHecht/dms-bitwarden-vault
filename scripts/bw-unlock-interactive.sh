#!/bin/bash
# Interactive unlock script for Bitwarden
SCRIPT_DIR="$(dirname "$0")"
HELPER="$SCRIPT_DIR/bw-helper.sh"
SYNC="$SCRIPT_DIR/bw-sync-to-plugin.sh"

echo "=== Bitwarden Vault Unlock ==="
echo ""

# Check current status
status=$("$HELPER" status 2>/dev/null)
if echo "$status" | grep -q '"status":"unlocked"'; then
    echo "Vault is already unlocked!"
    echo ""
    read -p "Press Enter to sync items and close..."
    python3 "$SYNC" sync
    exit 0
fi

# Unlock the vault
echo "Enter your master password to unlock:"
echo ""
session=$(bw unlock --raw 2>/dev/null)

if [ -n "$session" ]; then
    # Save session
    "$HELPER" save-session "$session"
    echo ""
    echo "✓ Vault unlocked successfully!"
    echo ""
    echo "Syncing items to launcher..."
    python3 "$SYNC" sync
    echo ""
    echo "✓ Done! Refreshing launcher..."
    # Reload settings in memory via IPC, then reopen spotlight
    sleep 0.3
    dms ipc call bitwarden reload &>/dev/null
    dms ipc call spotlight close &>/dev/null &
    sleep 0.2
    dms ipc call spotlight openQuery "bw " &>/dev/null &
    exit 0
else
    echo ""
    echo "✗ Failed to unlock vault"
    echo ""
    read -p "Press Enter to close..."
fi
