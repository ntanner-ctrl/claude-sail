---
name: security-warning
description: Warns when editing files that may contain sensitive data or credentials
hooks:
  - event: PreToolUse
    tools:
      - Write
      - Edit
    pattern: "**/.env*|**/credentials*|**/secrets*|**/*.pem|**/*.key|**/*secret*|**/*password*|**/*token*|**/config.json|**/settings.json|**/*.p12|**/*.pfx|**/*.jks|**/service-account*.json|**/*keyfile*"
---

# Security Warning

You are about to write to a file that matches sensitive-data patterns. Proceed carefully.

## Before Writing, Verify

### No Hardcoded Secrets
Scan the content you are about to write. If ANY of these appear as literal values (not environment variable references), STOP and refactor:

- API keys, tokens, or bearer credentials
- Passwords or passphrases
- Private keys (RSA, EC, Ed25519)
- Database connection strings with embedded credentials
- OAuth client secrets
- AWS access key IDs and secret access keys
- GCP service account JSON keys
- Webhook signing secrets
- Encryption keys or initialization vectors

### Environment Variable Pattern
Every secret value MUST come from the environment or a secrets manager, never from source code:

```python
# WRONG -- hardcoded secret
API_KEY = "sk-1234567890abcdef"

# RIGHT -- from environment
API_KEY = os.environ["API_KEY"]
```

```typescript
// WRONG
const dbPassword = "hunter2";

// RIGHT
const dbPassword = process.env.DB_PASSWORD!;
```

```yaml
# WRONG -- config.yml
database:
  password: "mysecretpassword"

# RIGHT -- config.yml referencing env
database:
  password: ${DATABASE_PASSWORD}
```

### Gitignore Check
If this file will contain real secret values:
1. Confirm it is listed in `.gitignore` BEFORE writing
2. If `.gitignore` does not cover it, add the pattern first
3. If a `.env.example` or equivalent exists, ensure it has placeholder values for documentation

### File Permissions
For private key files (`.pem`, `.key`, `.p12`), recommend restrictive permissions:
```bash
chmod 600 path/to/private.key
```

## Common Safe Patterns

| Pattern | Use Case |
|---------|----------|
| `.env.example` with `YOUR_KEY_HERE` placeholders | Document required variables (commit this) |
| `.env` with real values | Local development (gitignore this) |
| Secrets manager references | Production (AWS SSM, Vault, GCP Secret Manager) |
| `config.template.json` + `config.json` | Template committed, real config gitignored |

## If You Must Write a Secret (Testing, Local Dev)

1. Confirm the file is gitignored
2. Use obviously-fake values when possible (`test-key-not-real`, `localhost-only-password`)
3. Add a comment marking it as a local-only value
4. Never write production credentials -- reference a secrets manager instead
