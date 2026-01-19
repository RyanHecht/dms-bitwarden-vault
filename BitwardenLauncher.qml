import QtQuick
import Quickshell
import qs.Services

Item {
    id: root

    property var pluginService: null
    property string trigger: "."

    signal itemsChanged()

    property string pluginDir: Qt.resolvedUrl(".").toString().replace("file://", "").replace(/\/$/, "")
    property string helperScript: pluginDir + "/scripts/bw-helper.sh"
    property string syncScript: pluginDir + "/scripts/bw-sync-to-plugin.sh"

    Component.onCompleted: {
        if (pluginService) {
            trigger = pluginService.loadPluginData("bitwardenLauncher", "trigger", ".")
        }
    }

    // Parse type filter from query (e.g., "p2" for passwords+TOTP)
    // Returns { filter: {p, u, 2, c, n}, searchQuery: string }
    function parseTypeFilter(query) {
        const result = { filter: null, searchQuery: query || "" }
        
        // Look for filter pattern at start: only valid filter chars [pu2cn]
        // followed by space+search OR end of string
        // e.g., "p2 github" -> filter p+2, search "github"
        // e.g., "p2" -> filter p+2, no search
        // e.g., "github" -> no filter, search "github"
        // e.g., "pgithub" -> no filter (p not followed by space), search "pgithub"
        const match = (query || "").match(/^([pu2cn]+)(?:\s+(.*))?$/i)
        if (match) {
            const filterChars = match[1].toLowerCase()
            result.searchQuery = match[2] || ""
            result.filter = {
                p: filterChars.includes('p'),  // passwords
                u: filterChars.includes('u'),  // usernames
                '2': filterChars.includes('2'), // TOTP
                c: filterChars.includes('c'),  // cards
                n: filterChars.includes('n')   // notes
            }
        }
        
        return result
    }

    function getItems(query) {
        let unlocked = false
        let items = []
        
        if (pluginService) {
            unlocked = pluginService.loadPluginData("bitwardenLauncher", "vaultUnlocked", false)
            // Read cached items from pluginService (now stored securely, only item metadata)
            const itemsJson = pluginService.loadPluginData("bitwardenLauncher", "cachedItems", "[]")
            try {
                items = JSON.parse(itemsJson)
                if (!Array.isArray(items)) items = []
            } catch (e) {
                items = []
            }
        }

        let results = []

        if (!unlocked) {
            return [{
                name: "🔒 Unlock Bitwarden Vault",
                icon: "material:lock_open",
                comment: "Run bw unlock, save session, then Refresh",
                action: "unlock:",
                categories: ["Bitwarden Vault"]
            }, {
                name: "🔄 Refresh Status",
                icon: "material:refresh", 
                comment: "Check if vault is unlocked",
                action: "refresh:",
                categories: ["Bitwarden Vault"]
            }]
        }

        if (items.length === 0) {
            return [{
                name: "🔄 Load Vault Items",
                icon: "material:download",
                comment: "Fetch items from Bitwarden",
                action: "load:",
                categories: ["Bitwarden Vault"]
            }]
        }

        // Parse type filter and search query
        const parsed = parseTypeFilter(query)
        const typeFilter = parsed.filter
        const searchQuery = parsed.searchQuery.toLowerCase()

        for (let i = 0; i < items.length && results.length < 48; i++) {
            const item = items[i]
            const name = item.name || ""
            const login = item.login || {}
            const username = login.username || ""
            const uris = login.uris || []
            const uri = uris.length > 0 ? (uris[0].uri || "") : ""
            
            if (searchQuery && 
                !name.toLowerCase().includes(searchQuery) &&
                !username.toLowerCase().includes(searchQuery) &&
                !uri.toLowerCase().includes(searchQuery)) {
                continue
            }

            const itemType = item.type

            if (itemType === 1 && login) {
                // Show username if no filter or 'u' filter
                if (username && (!typeFilter || typeFilter.u)) {
                    results.push({
                        name: name,
                        icon: "material:person",
                        comment: "Copy username: " + username,
                        action: "username:" + item.id,
                        categories: ["Bitwarden Vault"]
                    })
                }
                // Show password if no filter or 'p' filter
                if (login.password && (!typeFilter || typeFilter.p)) {
                    results.push({
                        name: name,
                        icon: "material:key",
                        comment: "Copy password" + (username ? " • " + username : ""),
                        action: "password:" + item.id,
                        categories: ["Bitwarden Vault"]
                    })
                }
                // Show TOTP if no filter or '2' filter
                if (login.totp && (!typeFilter || typeFilter['2'])) {
                    results.push({
                        name: name,
                        icon: "material:schedule",
                        comment: "Copy TOTP code" + (username ? " • " + username : ""),
                        action: "totp:" + item.id,
                        categories: ["Bitwarden Vault"]
                    })
                }
            } else if (itemType === 2 && (!typeFilter || typeFilter.n)) {
                results.push({
                    name: name,
                    icon: "material:note",
                    comment: "Copy secure note",
                    action: "notes:" + item.id,
                    categories: ["Bitwarden Vault"]
                })
            } else if (itemType === 3 && (!typeFilter || typeFilter.c)) {
                const card = item.card || {}
                results.push({
                    name: name,
                    icon: "material:credit_card",
                    comment: ((card.brand || "") + " " + (card.cardholderName || "")).trim(),
                    action: "card:" + item.id,
                    categories: ["Bitwarden Vault"]
                })
            }
        }

        // Add utility items at end
        results.push({
            name: "🔄 Sync Vault",
            icon: "material:sync",
            comment: "Sync with Bitwarden server",
            action: "sync:",
            categories: ["Bitwarden Vault"]
        })
        results.push({
            name: "🔒 Lock Vault",
            icon: "material:lock",
            comment: "Lock the vault",
            action: "lock:",
            categories: ["Bitwarden Vault"]
        })

        return results.slice(0, 50)
    }

    function executeItem(item) {
        if (!item || !item.action) return

        const parts = item.action.split(":")
        const actionType = parts[0]
        const itemId = parts.slice(1).join(":")

        const labels = {
            "password": "Password",
            "username": "Username", 
            "totp": "TOTP code",
            "card": "Card number",
            "notes": "Notes"
        }

        switch (actionType) {
            case "unlock":
                const terminal = Quickshell.env("TERMINAL") || "ghostty"
                const unlockScript = pluginDir + "/scripts/bw-unlock-interactive.sh"
                Quickshell.execDetached([terminal, "-e", "bash", unlockScript])
                break
            case "refresh":
                // Run sync script
                Quickshell.execDetached(["python3", syncScript, "sync"])
                ToastService.showInfo("Bitwarden", "Refreshing... reopen launcher to see changes")
                break
            case "load":
                Quickshell.execDetached(["python3", syncScript, "items"])
                ToastService.showInfo("Bitwarden", "Loading... reopen launcher to see items")
                break
            case "sync":
                Quickshell.execDetached(["bash", "-c", helperScript + " sync && python3 " + syncScript + " sync"])
                ToastService.showInfo("Bitwarden", "Syncing... reopen launcher when done")
                break
            case "lock":
                // Lock via helper AND update pluginService memory directly
                Quickshell.execDetached(["bash", helperScript, "lock"])
                if (pluginService) {
                    pluginService.savePluginData("bitwardenLauncher", "vaultUnlocked", false)
                    pluginService.savePluginData("bitwardenLauncher", "cachedItems", "[]")
                }
                ToastService.showInfo("Bitwarden", "Vault locked")
                break
            case "password":
            case "username":
            case "totp":
            case "card":
            case "notes":
                // Use array-based execution to avoid shell injection
                // First get the value, then pipe to wl-copy via separate process
                Quickshell.execDetached(["bash", "-c", 
                    "exec \"$1\" \"$2\" \"$3\" | wl-copy", 
                    "_", helperScript, actionType, itemId])
                ToastService.showInfo("Bitwarden", (labels[actionType] || actionType) + " copied")
                break
            case "noop":
                break
        }
    }

    onTriggerChanged: {
        if (pluginService) {
            pluginService.savePluginData("bitwardenLauncher", "trigger", trigger)
        }
    }
}
