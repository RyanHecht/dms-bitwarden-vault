#!/usr/bin/env python3
"""Sync Bitwarden vault state to DMS plugin settings"""
import json
import subprocess
import sys
import os
import time

HELPER = os.path.join(os.path.dirname(__file__), "bw-helper.sh")
PLUGIN_SETTINGS = os.path.expanduser("~/.config/DankMaterialShell/plugin_settings.json")

def run_helper(cmd):
    result = subprocess.run(["bash", HELPER, cmd], capture_output=True, text=True)
    return result.stdout.strip()

def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "sync"
    
    # Load existing settings
    try:
        with open(PLUGIN_SETTINGS, 'r') as f:
            settings = json.load(f)
    except:
        settings = {}
    
    if 'bitwardenLauncher' not in settings:
        settings['bitwardenLauncher'] = {'enabled': True}
    
    if action in ("status", "sync"):
        # Check status
        status_json = run_helper("status")
        try:
            status = json.loads(status_json)
            unlocked = status.get("status") == "unlocked"
        except:
            unlocked = False
        
        settings['bitwardenLauncher']['vaultUnlocked'] = unlocked
        print(f"Vault unlocked: {unlocked}")
    
    if action in ("items", "sync") and settings['bitwardenLauncher'].get('vaultUnlocked', False):
        # Load items - store only safe metadata (no passwords/secrets)
        print("Loading items from vault...")
        items_json = run_helper("list")
        try:
            items = json.loads(items_json)
            if isinstance(items, list):
                # Strip sensitive data - only keep metadata needed for search/display
                safe_items = []
                for item in items:
                    safe_item = {
                        "id": item.get("id"),
                        "name": item.get("name"),
                        "type": item.get("type"),
                        "notes": bool(item.get("notes")),  # Just flag, not content
                    }
                    if item.get("login"):
                        login = item["login"]
                        safe_item["login"] = {
                            "username": login.get("username"),
                            "uris": login.get("uris", []),
                            "password": bool(login.get("password")),  # Just flag
                            "totp": bool(login.get("totp")),  # Just flag
                        }
                    if item.get("card"):
                        card = item["card"]
                        safe_item["card"] = {
                            "brand": card.get("brand"),
                            "cardholderName": card.get("cardholderName"),
                        }
                    safe_items.append(safe_item)
                
                settings['bitwardenLauncher']['cachedItems'] = json.dumps(safe_items)
                print(f"Loaded {len(safe_items)} items (metadata only)")
        except Exception as e:
            print(f"Failed to load items: {e}")
    
    if action == "lock":
        run_helper("lock")
        settings['bitwardenLauncher']['vaultUnlocked'] = False
        settings['bitwardenLauncher']['cachedItems'] = '[]'
        print("Vault locked")
    
    # Save settings with atomic write to trigger file watchers properly
    import tempfile
    temp_path = PLUGIN_SETTINGS + ".tmp"
    with open(temp_path, 'w') as f:
        json.dump(settings, f, indent=2)
        f.flush()
        os.fsync(f.fileno())
    
    # Atomic rename to trigger inotify
    os.rename(temp_path, PLUGIN_SETTINGS)
    
    print("Settings saved")

if __name__ == "__main__":
    main()
