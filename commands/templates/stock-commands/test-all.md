---
description: You MUST run this after ANY implementation changes. Detects test framework and runs full suite to catch regressions.
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# Test Runner

Run all tests for this project with automatic framework detection.

## Arguments

Parse `$ARGUMENTS` for:
- `--coverage` or `-c`: Include coverage reporting
- `--fast` or `-f`: Skip slow/integration tests
- `--verbose` or `-v`: Verbose output
- `--watch` or `-w`: Watch mode (if framework supports it)
- `[pattern]`: Run only tests matching pattern

## Execution

### Step 1: Detect Test Framework

Check for these indicators in order. Use the FIRST match -- do not run multiple frameworks unless the project explicitly uses them (e.g., separate `package.json` scripts for unit vs e2e).

| Priority | Indicator | Framework | Base Command |
|----------|-----------|-----------|-------------|
| 1 | `package.json` script named `test` | npm test | `npm test` |
| 2 | `pytest.ini` or `[tool.pytest.ini_options]` in `pyproject.toml` | pytest | `python -m pytest` |
| 3 | `conftest.py` anywhere | pytest | `python -m pytest` |
| 4 | `Cargo.toml` | cargo test | `cargo test` |
| 5 | `go.mod` | go test | `go test ./...` |
| 6 | `mix.exs` | ExUnit | `mix test` |
| 7 | `Gemfile` with `rspec` | RSpec | `bundle exec rspec` |
| 8 | `Makefile` with `test` target | make | `make test` |

**For Node projects**, also check `package.json` to identify the actual test runner (Jest, Vitest, Mocha, Playwright, etc.) since this affects flag syntax.

**If `package.json` has a `test` script:** Always prefer `npm test` (or `yarn test` / `pnpm test` based on lockfile) over calling the framework directly. The script may include necessary setup.

### Step 2: Prepare Environment

**Python:**
```bash
# Activate virtual environment if present
for dir in .venv venv env; do
    [ -d "$dir" ] && source "$dir/bin/activate" && break
done
```

**Node:**
```bash
# Check which package manager
if [ -f "pnpm-lock.yaml" ]; then PM="pnpm"
elif [ -f "yarn.lock" ]; then PM="yarn"
elif [ -f "bun.lockb" ]; then PM="bun"
else PM="npm"
fi

# Ensure dependencies installed
[ ! -d "node_modules" ] && $PM install
```

### Step 3: Build Test Command

Apply flags based on detected framework:

**pytest:**
```bash
cmd="python -m pytest"
[ "$verbose" = true ] && cmd="$cmd -v"
[ "$coverage" = true ] && cmd="$cmd --cov=. --cov-report=term-missing"
[ "$fast" = true ] && cmd="$cmd -m 'not slow and not integration'"
[ -n "$pattern" ] && cmd="$cmd -k '$pattern'"
```

**Jest / Vitest (via npm):**
```bash
cmd="$PM test"
[ "$coverage" = true ] && cmd="$cmd -- --coverage"
[ "$fast" = true ] && cmd="$cmd -- --testPathIgnorePatterns='integration|e2e'"
[ -n "$pattern" ] && cmd="$cmd -- --testNamePattern='$pattern'"
[ "$watch" = true ] && cmd="$cmd -- --watch"
```

**cargo test:**
```bash
cmd="cargo test"
[ -n "$pattern" ] && cmd="$cmd $pattern"
[ "$verbose" = true ] && cmd="$cmd -- --nocapture"
```

**go test:**
```bash
cmd="go test ./..."
[ "$verbose" = true ] && cmd="$cmd -v"
[ "$coverage" = true ] && cmd="$cmd -coverprofile=coverage.out"
[ -n "$pattern" ] && cmd="$cmd -run '$pattern'"
[ "$fast" = true ] && cmd="$cmd -short"
```

### Step 4: Execute and Report

Run the command. After execution, report:

```markdown
## Test Results

**Framework:** [detected framework]
**Command:** `[exact command run]`
**Duration:** [time]

### Summary
- [N] passed
- [N] failed
- [N] skipped

### Failed Tests (if any)
1. `test_file::test_name`
   Error: [first few lines of failure output]

2. ...

### Coverage (if --coverage)
- Overall: [N]%
- Files below 50%:
  - `path/to/file.py` ([N]%)
  - ...
```

### Step 5: Interpret Results

- **All passed:** Report success, note any skipped tests
- **Failures:** For each failure, briefly explain the likely cause based on the error message. If the failure relates to code you just changed, say so explicitly.
- **No tests found:** Warn the user and suggest creating tests for the modules they are working on

---

$ARGUMENTS
