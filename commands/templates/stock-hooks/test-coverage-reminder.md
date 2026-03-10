---
name: test-coverage-reminder
description: Reminds to check for corresponding test files when editing source modules
hooks:
  - event: PostToolUse
    tools:
      - Write
      - Edit
    pattern: "src/**/*.{py,ts,js,tsx,jsx,rs,go}|lib/**/*.{py,rb}|app/**/*.{py,ts,js,rb}|**/*.py"
---

# Test Coverage Reminder

When you create or edit a source file, pause and verify test coverage before moving on.

## Immediate Actions

1. **Locate the corresponding test file** using the conventions below
2. **If no test file exists** and you added new public API, flag this to the user: "No test file found for `{module}`. Want me to create one?"
3. **If a test file exists**, check whether the function/method you just modified has coverage
4. **If you added a new code path** (branch, error case, edge condition), verify a test exercises it

## Test File Location Conventions

| Language | Source Pattern | Test File Patterns |
|----------|--------------|-------------------|
| Python | `src/foo.py` | `tests/test_foo.py`, `tests/unit/test_foo.py`, `foo_test.py` |
| TypeScript/JS | `src/foo.ts` | `src/__tests__/foo.test.ts`, `src/foo.spec.ts`, `tests/foo.test.ts` |
| Rust | `src/foo.rs` | `tests/foo.rs`, inline `#[cfg(test)] mod tests` in same file |
| Go | `pkg/foo.go` | `pkg/foo_test.go` (same package, same directory) |
| Ruby | `app/foo.rb` | `spec/foo_spec.rb`, `test/foo_test.rb` |

## What To Check

- **New public function/method?** It needs at least one test covering the happy path.
- **Changed function signature?** Existing tests may need updating -- check for compile/type errors in test files.
- **Added error handling?** Add a test that triggers the error path.
- **Modified conditional logic?** Ensure both branches have coverage.
- **Changed return type or shape?** Tests asserting on the old shape will silently pass with wrong data -- verify assertions match.

## When To Skip This

- Documentation-only or comment-only changes
- Configuration files, data files, migration files
- Refactors that do not change public behavior (rename, extract method) -- existing tests should still pass
- Files in directories explicitly excluded from testing (vendored code, generated code)

## Auto-Detection Hint

If you are unsure where tests live, run:
```bash
# Find test directories
find . -type d -name "tests" -o -name "__tests__" -o -name "spec" -o -name "test" | head -10

# Find test files matching a module name
find . -name "*test*{module_name}*" -o -name "*{module_name}*test*" -o -name "*{module_name}*spec*" | head -10
```
