---
description: Use to freeze a directory to prevent Claude from modifying it. Run with a directory path to add a freeze, or with no arguments to list currently frozen directories.
arguments:
  - name: directory
    description: Directory path to freeze (absolute or relative). Omit to list frozen directories.
    required: false
  - name: reason
    description: Reason for freezing (e.g. "production config — do not touch")
    required: false
---

# Freeze

Add a directory to the frozen list to prevent accidental modification. Frozen directories are tracked in `.claude/frozen-dirs.json` and enforced by the `check-frozen-dirs` hook.

## Modes

- **`/freeze <directory>`** — Freeze a directory (prompts for optional reason)
- **`/freeze`** — List all currently frozen directories

---

## Process: Freeze a Directory

### Step 1: Resolve Absolute Path

Normalize the provided path to an absolute path. Never store relative paths.

```bash
# Prefer realpath; fall back to combining git root + relative path
realpath "$DIRECTORY" 2>/dev/null \
  || echo "$(git rev-parse --show-toplevel 2>/dev/null)/$DIRECTORY"
```

- Strip trailing slashes from the result.
- If the directory does not exist, warn the user and ask them to confirm before proceeding. Do not silently freeze non-existent paths.

### Step 2: Ask for a Reason (if not provided via `--reason`)

If `--reason` was not supplied as an argument, prompt:

```
Reason for freezing (press Enter to use default: "Frozen by user"):
>
```

Use the user's input as the reason. If blank, default to `"Frozen by user"`.

### Step 3: Load or Create State File

State file: `.claude/frozen-dirs.json` (in the current project root).

If the file does not exist:
```bash
mkdir -p .claude
echo '{"frozen": []}' > .claude/frozen-dirs.json
```

If it exists but is malformed JSON, stop and report the parse error — do not overwrite.

### Step 4: Check for Duplicate

Search the existing `frozen` array for an entry whose `path` matches the normalized absolute path.

If found:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ALREADY FROZEN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Path:      [absolute path]
  Reason:    [existing reason]
  Frozen at: [existing timestamp]

  No changes made.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Stop here.

### Step 5: Append Entry and Write

Append a new object to the `frozen` array:

```json
{
  "path": "/absolute/normalized/path",
  "reason": "user-provided reason or default",
  "frozen_at": "2025-01-15T14:00:00Z"
}
```

Timestamp format: `date -u +%Y-%m-%dT%H:%M:%SZ`

Write the updated JSON back to `.claude/frozen-dirs.json`.

### Step 6: Confirm

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  DIRECTORY FROZEN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Path:      [absolute path]
  Reason:    [reason]
  Frozen at: [UTC timestamp]

  Claude will refuse write operations inside this directory.
  To unfreeze: /unfreeze [directory]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Process: List Frozen Directories

When invoked with no arguments, load `.claude/frozen-dirs.json` and display all entries.

If the file does not exist or `frozen` is empty:

```
No directories are currently frozen.
```

Otherwise:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  FROZEN DIRECTORIES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  [1] /absolute/path/one
      Reason:    production config — do not touch
      Frozen at: 2025-01-15T14:00:00Z

  [2] /absolute/path/two
      Reason:    Frozen by user
      Frozen at: 2025-01-16T09:30:00Z

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  2 frozen director(ies) total
  To unfreeze: /unfreeze [directory]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## State File Schema

`.claude/frozen-dirs.json`:

```json
{
  "frozen": [
    {
      "path": "/absolute/path/to/dir",
      "reason": "user-provided reason",
      "frozen_at": "2025-01-15T14:00:00Z"
    }
  ]
}
```

**Rules:**
- `path` is always absolute, trailing slashes stripped
- `frozen_at` is always UTC ISO-8601: `YYYY-MM-DDTHH:MM:SSZ`
- Entries are append-only — this command never removes entries (use `/unfreeze`)

## Integration

- **Enforced by:** `check-frozen-dirs` PreToolUse hook (blocks Write/Edit/Bash inside frozen paths)
- **Complementary:** `/unfreeze` removes an entry from the frozen list
- **State file:** `.claude/frozen-dirs.json` in the project root
