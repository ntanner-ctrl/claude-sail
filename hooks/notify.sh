#!/bin/bash
# Claude Code Notification Hook - Desktop Alerts
# Adapted from TheDecipherist/claude-code-mastery
#
# Installation: Add to ~/.claude/settings.json:
# {
#   "hooks": {
#     "Notification": [{
#       "matcher": "*",
#       "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify.sh" }]
#     }]
#   }
# }

# Fail-open: Don't block on notification errors
set +e

# Hook runtime toggle — skip if disabled via env var
HOOK_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
if [[ ",${SAIL_DISABLED_HOOKS}," == *",${HOOK_NAME},"* ]]; then
    exit 0
fi

# Read JSON input from stdin
input=$(cat)

# Extract notification message (fail-open: default to generic if parse fails)
message=$(echo "$input" | jq -r '.message // "Claude Code needs attention"' 2>/dev/null)
if [[ -z "$message" || "$message" == "null" ]]; then
    message="Claude Code needs attention"
fi

# Truncate long messages
if [[ ${#message} -gt 100 ]]; then
    message="${message:0:97}..."
fi

# Escape special characters for shell/powershell
escape_message() {
    echo "$1" | sed "s/'/'\\\\''/g"
}

escaped_message=$(escape_message "$message")

# Platform-specific notifications
notify_macos() {
    osascript -e "display notification \"$escaped_message\" with title \"Claude Code\" sound name \"Glass\"" 2>/dev/null
}

notify_linux() {
    # Try notify-send (most Linux distros)
    if command -v notify-send &>/dev/null; then
        notify-send "Claude Code" "$message" --icon=dialog-information 2>/dev/null
        return 0
    fi
    return 1
}

notify_wsl() {
    # WSL: Use PowerShell Toast notifications
    powershell.exe -Command "
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

        \$template = @'
<toast>
    <visual>
        <binding template='ToastText02'>
            <text id='1'>Claude Code</text>
            <text id='2'>$escaped_message</text>
        </binding>
    </visual>
    <audio src='ms-winsoundevent:Notification.Default'/>
</toast>
'@

        \$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        \$xml.LoadXml(\$template)
        \$toast = [Windows.UI.Notifications.ToastNotification]::new(\$xml)
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Claude Code').Show(\$toast)
    " 2>/dev/null
}

notify_fallback() {
    # Terminal bell as last resort
    printf '\a'
}

# Detect platform and send notification
if [[ "$OSTYPE" == "darwin"* ]]; then
    notify_macos || notify_fallback
elif grep -qi microsoft /proc/version 2>/dev/null; then
    # WSL detected
    notify_wsl || notify_linux || notify_fallback
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    notify_linux || notify_fallback
else
    notify_fallback
fi

# Always exit 0 (fail-open)
exit 0
