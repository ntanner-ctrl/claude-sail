---
name: interface-validation
description: "Template hook: validates that modules follow a consistent interface pattern. Copy and customize for your project."
hooks:
  - event: PostToolUse
    tools:
      - Write
      - Edit
    pattern: "**/*.py"
---

# Interface Validation Hook (Template)

This is a **template** -- copy it, rename it, and customize it for your project's specific interface contracts.

## How to Customize

1. Copy this file to your project's `.claude/hooks/` directory
2. Rename to match your interface (e.g., `service-interface.md`, `handler-contract.md`)
3. Update the `pattern` in YAML frontmatter to match your files:
   ```yaml
   pattern: "**/services/*_service.py"
   ```
4. Replace the example interface below with your actual required contract
5. Update the validation checklist to match your requirements

## What This Hook Does

After you create or edit a file matching the pattern, it reminds you to verify the file conforms to the project's interface contract. This catches drift before it becomes a refactoring problem.

## Template: Define Your Required Interface

Replace this section with your project's actual interface. Here are examples for common patterns:

### Example A: Service Pattern (Python)
```python
# Required interface for *_service.py files
class SomeService:
    def __init__(self, config: ServiceConfig, logger: Logger):
        """All services accept config and logger."""
        ...

    async def start(self) -> None:
        """Called on application startup. Acquire resources here."""
        ...

    async def stop(self) -> None:
        """Called on application shutdown. Release resources here."""
        ...

    def health(self) -> HealthStatus:
        """Return current health. Must not raise."""
        ...
```

### Example B: Handler Pattern (TypeScript)
```typescript
// Required interface for *Handler.ts files
export interface Handler<TInput, TOutput> {
  validate(input: unknown): TInput;
  execute(input: TInput, context: RequestContext): Promise<TOutput>;
  // Optional: override for custom error mapping
  mapError?(error: unknown): HttpError;
}
```

### Example C: Plugin Pattern (Python)
```python
# Required interface for plugins/*.py files
class Plugin:
    name: str          # Unique identifier
    version: str       # SemVer string

    def register(self, app: Application) -> None:
        """Called once at startup. Register routes, hooks, etc."""
        ...

    def unregister(self) -> None:
        """Called on shutdown or hot-reload. Clean up."""
        ...
```

## Validation Checklist

When this hook triggers, verify the edited file against the contract:

- [ ] Required class/function/interface exists with the correct name
- [ ] Constructor/init signature matches (required parameters present)
- [ ] All required methods are implemented (not just `pass` or `raise NotImplementedError`)
- [ ] Return types match the contract (especially health/status methods)
- [ ] Error handling follows project conventions (custom exceptions, not bare raises)
- [ ] Lifecycle methods are present if the interface requires them (start/stop, register/unregister)

## When to Skip

- The file is a test file testing the interface
- The file is a base class or abstract definition of the interface itself
- The edit was documentation-only (docstrings, comments)

## Advanced: Multi-File Contracts

Some interfaces span multiple files (e.g., a service needs both `*_service.py` and `*_repository.py`). For these:

1. Create separate hook files for each pattern
2. Cross-reference: "If you created a new service, verify the corresponding repository also exists"
3. Check barrel exports / `__init__.py` registration
