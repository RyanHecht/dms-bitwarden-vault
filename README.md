# Bitwarden Vault Launcher for DMS

A DankMaterialShell launcher plugin that lets you search and copy credentials from your Bitwarden vault.

## Features

- 🔍 Search logins, cards, and secure notes
- 👤 Copy usernames with one click
- 🔑 Copy passwords with one click  
- ⏱️ Copy TOTP/2FA codes
- 💳 Copy card numbers
- 📝 Copy secure notes
- 🔄 Sync vault from launcher
- 🔒 Lock/unlock vault from launcher
- 🔎 Filter results by type (passwords, usernames, TOTP, cards, notes)

## Requirements

- **Bitwarden CLI** (`bw`) must be installed
- **jq** for JSON parsing (card number extraction)
- **wl-copy** for Wayland clipboard support
- You must be logged into Bitwarden
- Vault must be unlocked for access

### Install Dependencies

```bash
# Bitwarden CLI - Option 1: npm (recommended)
npm install -g @bitwarden/cli

# Bitwarden CLI - Option 2: npm to user directory (no sudo)
npm install -g @bitwarden/cli --prefix ~/.local

# Bitwarden CLI - Option 3: Download binary
# https://github.com/bitwarden/clients/releases

# Other dependencies (Fedora/Nobara)
sudo dnf install jq wl-clipboard

# Other dependencies (Arch)
sudo pacman -S jq wl-clipboard
```

### Login and Unlock

```bash
# Login to Bitwarden (one-time)
bw login

# Unlock vault (needed after each reboot/lock)
bw unlock

# The plugin will store the session token in $XDG_RUNTIME_DIR
```

## Installation

### Option 1: Copy to DMS plugins directory

```bash
cp -r /path/to/dms-bitwarden ~/.config/DankMaterialShell/plugins/bitwardenLauncher
dms restart
```

### Option 2: Symlink (for development)

```bash
ln -s /path/to/dms-bitwarden ~/.config/DankMaterialShell/plugins/bitwardenLauncher
dms restart
```

## Usage

1. Open the launcher (`Ctrl+Space` or click launcher button)
2. Type the trigger (default: `.`) followed by your search
3. Examples:
   - `. github` - Find GitHub accounts
   - `. visa` - Find Visa cards
   - `. ssh` - Find SSH keys/notes
4. Select the item type you want to copy:
   - 👤 Username
   - 🔑 Password
   - ⏱️ TOTP code
5. Press Enter to copy to clipboard

### Type Filters

Filter results by type using prefix characters before your search:

- `p` - Passwords only
- `u` - Usernames only
- `2` - TOTP codes only
- `c` - Cards only
- `n` - Notes only

Combine filters: `.p2 github` shows only passwords and TOTP for GitHub accounts.

### Workflow

1. **First launch**: If vault is locked, select "🔒 Unlock Bitwarden Vault" to open interactive terminal
2. **Load items**: After unlocking, select "🔄 Load Vault Items" to fetch items
3. **Search**: Type your search query to filter items
4. **Copy**: Select an item to copy its value to clipboard

### Utility Commands

- Type just `.` to see all items and utility options
- Select "🔄 Sync Vault" to sync with Bitwarden server
- Select "🔒 Lock Vault" to lock the vault

## Configuration

Open DMS Settings → Plugins → Bitwarden Vault to configure:

- **Trigger**: Change the activation keyword (default: `.`)

## Security

- Session tokens are stored in `$XDG_RUNTIME_DIR/bw-session` (memory-backed tmpfs)
- `XDG_RUNTIME_DIR` is **required** - the plugin will not fall back to `/tmp` for security
- Tokens are cleared when you lock the vault or log out
- Passwords and secrets are **never cached** - only item metadata (names, usernames, URLs) is stored
- Actual passwords/TOTP codes are fetched on demand from Bitwarden CLI when copied
- The plugin only reads from your vault, never writes

## Troubleshooting

### "Vault is locked" message

Use the "🔒 Unlock Bitwarden Vault" option in the launcher, which opens an interactive terminal to unlock. Alternatively, run manually:

```bash
bw unlock
```

Then use the plugin's "🔄 Refresh Status" option to detect the session.

### "Bitwarden CLI not found"

Make sure `bw` is in your PATH. The plugin checks these locations:
- `$PATH` (via `command -v bw`)
- `~/.local/bin/bw`
- `/usr/local/bin/bw`
- `/usr/bin/bw`

```bash
which bw
# If not found, add to PATH
export PATH="$HOME/.local/bin:$PATH"
```

### Items not showing

1. Select "🔄 Load Vault Items" from the launcher
2. Check vault status: `bw status`
3. Sync vault: `bw sync`
4. Restart DMS: `dms restart`

### "XDG_RUNTIME_DIR not set"

The plugin requires `XDG_RUNTIME_DIR` for secure session storage. This should be set automatically by your session manager. If not set, check your display manager configuration.

## Files

- `BitwardenLauncher.qml` - Main launcher component
- `BitwardenSettings.qml` - Settings panel UI
- `plugin.json` - Plugin manifest
- `scripts/bw-helper.sh` - Bash helper for Bitwarden CLI operations
- `scripts/bw-sync-to-plugin.sh` - Python script to sync vault state to DMS settings
- `scripts/bw-unlock-interactive.sh` - Interactive unlock terminal script

## License

MIT
