---
name: exfiltration-protection
enabled: true
event: bash
pattern: (curl|wget|nc|netcat)\s+.*\.(env|pem|key|secret|credentials|p12|pfx)
action: block
baseline: true
---

**BLOCKED: Potential secret exfiltration detected**

This command appears to be sending sensitive files over the network:
- `.env` - Environment variables (often contains API keys)
- `.pem`, `.key`, `.p12`, `.pfx` - Private keys and certificates
- `.secret`, `.credentials` - Credential files

**Why this is blocked:**
- Secrets sent over network can be intercepted
- Even HTTPS doesn't protect against malicious endpoints
- Audit logs may capture the transfer

**If this is intentional:**
- For backups: Use encrypted channels (scp, rsync over SSH)
- For deployments: Use secrets managers (Vault, AWS Secrets Manager)
- For debugging: Redact sensitive values first

**To proceed safely:**
1. Verify the destination is trusted
2. Use encrypted transport (HTTPS/SSH)
3. Consider if there's a safer alternative
