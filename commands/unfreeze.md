---
description: Use to unfreeze a directory that was previously frozen with /freeze. Run with a directory path to remove a single freeze, or with --all to clear all freezes.
arguments:
  - name: directory
    description: Directory path to unfreeze (absolute or relative). Omit if using --all.
    required: false
  - name: --all
    description: Clear all frozen directories at once.
    required: false
---

# Unfreeze

Remove a directory from the frozen list so Claude may modify it again. Reads and modifies `.claude/frozen-dirs.json`.

## Modes

- **`/unfreeze <directory>`** — Remove a single directory from the freeze list
- **`/unfreeze --all`** — Clear all frozen directories

---

## Process: Unfreeze a Single Directory

### Step 1: Check State File

Load `.claude/frozen-dirs.json` from the current project root.

If the file does not exist:

```
No directories are currently frozen.
```

Stop here.

If the file exists but is malformed JSON, stop and report the parse error — do not modify the file.

### Step 2: Resolve Absolute Path

Normalize the provided path to an absolute path using the same logic as `/freeze`:

```bash
# Strip trailing slashes first, then resolve
realpath "$DIRECTORY" 2>/dev/null \
  || echo "$(git rev-parse --show-toplevel 2>/dev/null)/$DIRECTORY"
```

- Strip trailing slashes from the result (so `/unfreeze src/auth/` matches stored `src/auth`).
- Use the resolved absolute path for all comparisons.

### Step 3: Search the Freeze List

Search the `frozen` array for an entry whose `path` exactly matches the resolved absolute path.

If no match is found:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  NOT FROZEN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Directory [resolved absolute path] is not frozen.

  No changes made.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Stop here.

### Step 4: Remove Entry and Write

Remove the matching entry from the `frozen` array. Write the updated JSON back to `.claude/frozen-dirs.json`.

### Step 5: Confirm

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  DIRECTORY UNFROZEN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Path:   [absolute path]
  Reason: [reason that was stored]

  Claude may now modify files in this directory.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Then display remaining frozen directories (see "Remaining Directories Display" below).

---

## Process: Unfreeze All (`--all`)

### Step 1: Check State File

Load `.claude/frozen-dirs.json` from the current project root.

If the file does not exist or `frozen` is empty:

```
No directories are currently frozen.
```

Stop here.

### Step 2: Confirm Before Clearing

Display the current freeze list and ask for confirmation:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  UNFREEZE ALL — [N] director(ies) will be unfrozen:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  [1] /absolute/path/one
      Reason: production config — do not touch

  [2] /absolute/path/two
      Reason: Frozen by user

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Proceed? (yes/no)
```

If the user responds anything other than `yes`, abort with "Unfreeze cancelled. No changes made."

### Step 3: Clear and Write

Set the `frozen` array to `[]`. Write the updated JSON back to `.claude/frozen-dirs.json`.

### Step 4: Confirm

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ALL DIRECTORIES UNFROZEN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  All directories unfrozen. Claude may now modify any path.
  To re-freeze: /freeze [directory]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Remaining Directories Display

After a single unfreeze, always show what remains. If the freeze list is now empty:

```
  Remaining: All directories unfrozen.
  To freeze again: /freeze [directory]
```

If entries remain:

```
  Remaining frozen directories:

  [1] /absolute/path/two
      Reason:    Frozen by user
      Frozen at: 2025-01-16T09:30:00Z

  To manage: /freeze | /unfreeze
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
- This command only removes entries — use `/freeze` to add them

## Integration

- **Enforced by:** `check-frozen-dirs` PreToolUse hook (blocks Write/Edit/Bash inside frozen paths)
- **Complementary:** `/freeze` adds an entry to the frozen list
- **State file:** `.claude/frozen-dirs.json` in the project root
