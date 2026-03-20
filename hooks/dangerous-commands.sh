#!/bin/bash
# Claude Code Dangerous Commands Blocker - PreToolUse Hook
# Uses exit code 2 to send feedback TO CLAUDE (not just block)
# Adapted from TheDecipherist/claude-code-mastery with enhancements
#
# Exit Codes:
#   0 = Allow operation (proceed silently)
#   1 = User-facing error (hook malfunction)
#   2 = Block with feedback TO CLAUDE (Claude sees stderr)
#
# Installation: Add to ~/.claude/settings.json PreToolUse hooks

# Fail-open: Don't let hook bugs block work
set +e

# Hook runtime toggle — skip if disabled via env var
HOOK_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
if [[ ",${SAIL_DISABLED_HOOKS}," == *",${HOOK_NAME},"* ]]; then
    exit 0
fi

# Audit logging — no-op fallback if utility not installed
audit_block() { :; }
source ~/.claude/hooks/_audit-log.sh 2>/dev/null || true

# Read JSON input from stdin
input=$(cat)

# Extract command (fail-open if can't parse)
cmd=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)

if [[ -z "$cmd" ]]; then
    exit 0  # No command, allow
fi

# Helper: Block with feedback to Claude
block_with_feedback() {
    local category="$1"
    local reason="$2"
    local suggestion="$3"

    echo "BLOCKED [$category]: $reason" >&2
    echo "" >&2
    echo "Suggestion: $suggestion" >&2
    audit_block "$HOOK_NAME" "$category" "$reason" "Bash" "${cmd:0:100}"
    exit 2
}

# =============================================================================
# DESTRUCTIVE RM PATTERNS (Surgical - allows rm -rf node_modules)
# =============================================================================

# rm -rf / (root)
if [[ "$cmd" =~ rm[[:space:]]+-rf[[:space:]]+/([[:space:]]|$) ]]; then
    block_with_feedback "DESTRUCTIVE" \
        "Refusing to delete root filesystem (/)" \
        "Use specific paths like ./directory or /path/to/safe/target"
fi

# rm -rf ~ (home directory)
if [[ "$cmd" =~ rm[[:space:]]+-rf[[:space:]]+~([[:space:]]|/|$) ]]; then
    block_with_feedback "DESTRUCTIVE" \
        "Refusing to delete home directory (~)" \
        "Use specific subdirectory like ~/Downloads/temp or ./local-dir"
fi

# rm -rf .. (parent escape)
if [[ "$cmd" =~ rm[[:space:]]+-rf[[:space:]]+\.\. ]]; then
    block_with_feedback "DESTRUCTIVE" \
        "Refusing parent directory escape (..)" \
        "Use explicit absolute paths to avoid accidental parent deletion"
fi

# rm -rf /* or ~/* (dangerous wildcards)
if [[ "$cmd" =~ rm[[:space:]]+-rf[[:space:]]+(/\*|~/\*) ]]; then
    block_with_feedback "DESTRUCTIVE" \
        "Refusing wildcard at dangerous level (/* or ~/*)" \
        "Use specific directory paths instead of wildcards at root/home level"
fi

# rm -rf /home (all users)
if [[ "$cmd" =~ rm[[:space:]]+-rf[[:space:]]+/home([[:space:]]|/|$) ]]; then
    block_with_feedback "DESTRUCTIVE" \
        "Refusing to delete /home (all user directories)" \
        "Use specific user directory like /home/username/specific-folder"
fi

# =============================================================================
# GIT FORCE PUSH TO PROTECTED BRANCHES
# =============================================================================

if [[ "$cmd" =~ git[[:space:]]+push.*(-f|--force) ]]; then
    if [[ "$cmd" =~ (main|master|production|release|develop) ]]; then
        block_with_feedback "GIT_SAFETY" \
            "Refusing force push to protected branch (main/master/production/release/develop)" \
            "Create a feature branch, push there, then open a PR. Or use 'git revert' for safe history changes."
    fi
fi

# =============================================================================
# WORLD-WRITABLE PERMISSIONS
# =============================================================================

if [[ "$cmd" =~ chmod[[:space:]]+(777|a\+rwx) ]]; then
    block_with_feedback "SECURITY" \
        "Refusing world-writable permissions (chmod 777/a+rwx)" \
        "Use chmod 755 for executables, chmod 644 for files, or chmod 700 for private directories"
fi

# =============================================================================
# REMOTE CODE EXECUTION (curl/wget piped to shell)
# =============================================================================

if [[ "$cmd" =~ (curl|wget)[[:space:]].*\|[[:space:]]*(sh|bash|zsh|python|perl|ruby) ]]; then
    block_with_feedback "SECURITY" \
        "Refusing remote code execution (pipe to shell)" \
        "Download first: curl -o script.sh URL, inspect with cat, then chmod +x && ./script.sh"
fi

# =============================================================================
# DIRECT DISK OPERATIONS
# =============================================================================

if [[ "$cmd" =~ dd[[:space:]].*of=/dev/(sd|hd|nvme|disk|loop) ]]; then
    block_with_feedback "DESTRUCTIVE" \
        "Refusing direct disk write (dd to block device)" \
        "Verify target with 'lsblk' first. Consider using loop devices for testing."
fi

if [[ "$cmd" =~ mkfs ]]; then
    block_with_feedback "DESTRUCTIVE" \
        "Refusing filesystem format (mkfs)" \
        "Triple-check target device with 'lsblk' and 'fdisk -l'. This erases all data."
fi

# =============================================================================
# POTENTIAL EXFILTRATION
# =============================================================================

if [[ "$cmd" =~ (curl|wget|nc|netcat)[[:space:]].*\.(env|pem|key|secret|credentials|p12|pfx) ]]; then
    block_with_feedback "SECURITY" \
        "Refusing potential secret exfiltration over network" \
        "Use encrypted channels (scp, rsync over SSH) or secrets managers for credential transfer"
fi

# =============================================================================
# HISTORY DESTRUCTION
# =============================================================================

if [[ "$cmd" =~ history[[:space:]]+-c ]] || [[ "$cmd" =~ \>[[:space:]]*(~/.bash_history|~/.zsh_history) ]]; then
    block_with_feedback "AUDIT" \
        "Refusing history destruction" \
        "If you need to remove sensitive commands, edit history file manually with care"
fi

# =============================================================================
# SUDO WITH STDIN PASSWORD (insecure)
# =============================================================================

if [[ "$cmd" =~ echo.*\|[[:space:]]*sudo ]]; then
    block_with_feedback "SECURITY" \
        "Refusing password piped to sudo (insecure)" \
        "Use 'sudo -S' only with secure input, or configure sudoers for passwordless specific commands"
fi

# =============================================================================
# All checks passed - allow the command
# =============================================================================

exit 0
