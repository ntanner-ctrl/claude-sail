---
description: You MUST use this when creating ANY new module or component. Generates files matching project conventions instead of guessing structure.
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
---

# Module Scaffolder

Generate new modules, components, or features by analyzing existing project conventions and replicating them -- not from generic templates.

## Arguments

Parse `$ARGUMENTS` for:
- Module type (if provided): `service`, `component`, `handler`, `model`, `route`, `middleware`, etc.
- Module name (if provided): Name of the new module

If either is missing, ask the user before proceeding.

## Scaffolding Process

### Step 1: Detect Project Type

Identify the project's language, framework, and conventions:

| Indicator | Project Type |
|-----------|-------------|
| `package.json` + `react` or `next` dep | React / Next.js |
| `package.json` + `express` or `fastify` dep | Node API |
| `package.json` + `svelte` dep | SvelteKit |
| `pyproject.toml` or `setup.py` + `django` | Django |
| `pyproject.toml` or `setup.py` + `fastapi` | FastAPI |
| `pyproject.toml` or `setup.py` (generic) | Python |
| `Cargo.toml` | Rust |
| `go.mod` | Go |
| `mix.exs` | Elixir |
| `Gemfile` + `rails` | Rails |

### Step 2: Find Existing Examples (Critical Step)

Before generating ANYTHING, find existing modules of the same type and study their conventions:

```bash
# Find existing files of the same type
# Adjust the search based on what type was requested
```

For each existing example, note:
1. **File location** -- Where does it live? What directory structure?
2. **Naming convention** -- snake_case, PascalCase, kebab-case? Suffix convention (`*_service.py`, `*.handler.ts`)?
3. **Internal structure** -- Imports, class vs function, export style
4. **Type annotations** -- How thorough? What style?
5. **Documentation** -- Docstrings? JSDoc? Inline comments?
6. **Error handling** -- Custom exceptions? Result types? Try/catch patterns?
7. **Testing** -- Where do tests live? What naming? What test framework?
8. **Registration** -- Are modules registered in an index file, barrel export, or config?

### Step 3: Generate Files

Generate files that match the project's existing conventions EXACTLY. Do not use generic templates -- replicate the patterns you found in Step 2.

**For each generated file:**
- Match the exact import style of existing modules
- Match the exact naming conventions
- Match the exact documentation style
- Include `TODO` markers for implementation-specific logic
- Include the test file with the correct naming and location

### Step 4: Register the Module

Check if the project uses any registration mechanism and update it:

```bash
# Barrel exports (index.ts, __init__.py)
# Route registration (routes.ts, urls.py)
# Module config (app.module.ts, settings.py INSTALLED_APPS)
# Dependency injection containers
```

If a registration file exists, add the new module to it.

### Step 5: Report

```markdown
## Scaffolding Complete

### Created Files
| File | Purpose |
|------|---------|
| `path/to/new_file.py` | [purpose] |
| `path/to/test_new_file.py` | Tests |

### Updated Files
| File | Change |
|------|--------|
| `path/to/index.ts` | Added export for new module |

### Conventions Applied
- [Convention 1 from existing code]
- [Convention 2 from existing code]
- Based on: `path/to/existing_similar_module.py`

### Next Steps
1. Implement the TODO sections
2. Run tests: `[test command]`
3. [Any project-specific follow-up]
```

## Convention Discovery Examples

### Python Service
```bash
# Find existing services
find . -name "*_service.py" -not -path "./.venv/*" | head -5
# Read one to learn the pattern
```

### React Component
```bash
# Find existing components
find . -path "*/components/*" -name "*.tsx" -not -path "*/node_modules/*" | head -10
# Check if using barrel exports
find . -path "*/components/*/index.ts" | head -5
# Check for co-located tests
find . -name "*.test.tsx" -o -name "*.spec.tsx" | head -5
# Check for co-located styles
find . -name "*.module.css" -o -name "*.styled.ts" | head -5
```

### Go Handler
```bash
# Find existing handlers
find . -name "*_handler.go" -o -name "*handler*.go" | head -5
# Check for interface definitions
grep -r "type.*Handler.*interface" --include="*.go" | head -5
```

### Express Route
```bash
# Find existing route files
find . -name "*.routes.ts" -o -name "*.router.ts" | head -5
# Check middleware patterns
grep -r "router\.\(use\|get\|post\)" --include="*.ts" | head -10
```

## Guardrails

- NEVER generate from a hardcoded template if existing examples exist in the project
- ALWAYS read at least one existing file of the same type before generating
- If NO existing example exists (first of its kind), ask the user for their preferred conventions
- Match line endings, indentation (tabs vs spaces, width), and trailing newlines of existing files

---

$ARGUMENTS
