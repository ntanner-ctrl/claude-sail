---
description: Use at session start or when something seems broken. Validates project config, deps, and build before investigating further.
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# Project Health Check

Validate that the project is properly configured and ready for development. Run each check and report results.

## Arguments

Parse `$ARGUMENTS` for:
- `--verbose` or `-v`: Show detailed output for each check
- `--fix`: Attempt to fix issues automatically where possible
- `--skip <check>`: Skip specific checks (deps, config, build, git, runtime)

## Health Checks

Run each check in order. For each, report PASS, WARN, or FAIL.

### 1. Project Detection

First, identify the project type to determine which checks apply:

```bash
# Detect project type(s)
[ -f "package.json" ]    && echo "node"
[ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "requirements.txt" ] && echo "python"
[ -f "Cargo.toml" ]     && echo "rust"
[ -f "go.mod" ]          && echo "go"
[ -f "mix.exs" ]         && echo "elixir"
[ -f "Gemfile" ]         && echo "ruby"
[ -f "Makefile" ]        && echo "make"
```

Projects may be multi-language (e.g., Python backend + Node frontend). Check all that apply.

### 2. Dependencies Check

**Goal:** All dependencies are installed and resolvable.

| Project Type | Check Command | Pass Condition |
|-------------|--------------|----------------|
| Node | `npm ls 2>&1` (or yarn/pnpm equivalent) | No `MISSING` or `ERR!` in output |
| Python | `pip check` | Exit code 0 |
| Rust | `cargo check 2>&1` | Exit code 0 |
| Go | `go mod verify` | Exit code 0 |
| Ruby | `bundle check` | Exit code 0 |

**If `--fix`:** Run the appropriate install command (`npm install`, `pip install -r requirements.txt`, etc.)

**Status logic:**
- PASS: All dependencies satisfied
- WARN: Dependencies present but outdated or have non-critical audit findings
- FAIL: Missing dependencies or resolution failures

### 3. Configuration Check

**Goal:** Required config files exist, optional ones are documented.

Check for:
```bash
# Essential project files
[ -f "README.md" ]       || echo "WARN: No README.md"
[ -f ".gitignore" ]      || echo "WARN: No .gitignore"

# Environment configuration
if [ -f ".env.example" ] && [ ! -f ".env" ]; then
    echo "WARN: .env.example exists but .env is missing -- copy and fill in values"
fi

# Claude Code configuration
[ -d ".claude" ]         || echo "INFO: No .claude/ directory"
[ -f ".claude/CLAUDE.md" ] || echo "INFO: No project CLAUDE.md"

# Validate JSON/YAML configs (syntax only)
for f in $(find . -maxdepth 3 -name "*.json" -not -path "*/node_modules/*" -not -path "*/.git/*" | head -20); do
    python3 -c "import json; json.load(open('$f'))" 2>/dev/null || echo "FAIL: Invalid JSON: $f"
done
```

**Status logic:**
- PASS: All required configs present and valid
- WARN: Optional configs missing or .env not set up
- FAIL: Required configs missing or malformed

### 4. Build Check

**Goal:** The project compiles/builds without errors.

| Project Type | Check Command | Notes |
|-------------|--------------|-------|
| Node (TS) | `npx tsc --noEmit` | Type checking only, no output files |
| Node (JS) | Skip or `npm run build` if script exists | |
| Python | `python -m py_compile [changed files]` | Syntax check |
| Python (typed) | `mypy . --ignore-missing-imports` if mypy installed | |
| Rust | `cargo check` | Faster than `cargo build` |
| Go | `go build ./...` | Compile check |

**Also check for lint scripts:**
```bash
# If a lint script exists, run it
[ -f "package.json" ] && grep -q '"lint"' package.json && echo "Lint available: npm run lint"
```

**Status logic:**
- PASS: Builds clean
- WARN: Builds with warnings
- FAIL: Build errors

### 5. Git Check

**Goal:** Repository is in a known state.

```bash
# Current branch
git branch --show-current

# Working tree status
git status --short | head -20

# Remote sync status
git rev-list --left-right --count HEAD...@{upstream} 2>/dev/null
# Output: "ahead behind" -- e.g., "3 0" means 3 commits ahead

# Check for merge conflicts
git diff --check 2>/dev/null
```

**Status logic:**
- PASS: Clean working tree, synced with remote
- WARN: Uncommitted changes or behind remote
- FAIL: Merge conflicts, detached HEAD, no remote configured

### 6. Runtime Check (Optional)

**Goal:** Required services and tools are available.

```bash
# Check for common required tools
for tool in docker git curl; do
    command -v $tool > /dev/null 2>&1 || echo "WARN: $tool not installed"
done

# Check for running services (if docker-compose.yml exists)
if [ -f "docker-compose.yml" ] || [ -f "compose.yml" ]; then
    docker compose ps 2>/dev/null || echo "INFO: Docker Compose services not running"
fi

# Check common ports
for port in 3000 5432 6379 8080; do
    (echo > /dev/tcp/localhost/$port) 2>/dev/null && echo "INFO: Port $port in use"
done
```

## Output Format

```markdown
## Project Health Check

**Project type:** [detected type(s)]
**Directory:** [cwd]

| Check | Status | Details |
|-------|--------|---------|
| Dependencies | PASS/WARN/FAIL | [summary] |
| Configuration | PASS/WARN/FAIL | [summary] |
| Build | PASS/WARN/FAIL | [summary] |
| Git | PASS/WARN/FAIL | [summary] |
| Runtime | PASS/WARN/FAIL | [summary] |

### Issues to Address
1. [FAIL] [description and fix command]
2. [WARN] [description and suggested action]

### Quick Fixes (if --fix not used)
- `[command]` -- [what it fixes]
```

---

$ARGUMENTS
