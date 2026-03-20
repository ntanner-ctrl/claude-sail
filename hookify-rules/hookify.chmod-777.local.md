---
name: chmod-777-protection
enabled: true
event: bash
pattern: chmod\s+(777|a\+rwx)
action: block
baseline: true
---

**BLOCKED: World-writable permissions detected**

`chmod 777` or `chmod a+rwx` makes files readable, writable, and executable by ALL users on the system. This is a security vulnerability.

**Safe alternatives:**
- `chmod 755` - Owner: rwx, Group/Others: rx (for executables)
- `chmod 644` - Owner: rw, Group/Others: r (for regular files)
- `chmod 700` - Owner only: rwx (for private directories)
- `chmod 600` - Owner only: rw (for private files like SSH keys)

**When 777 seems needed:**
- Docker volume mounts → Use proper user mapping instead
- Web server uploads → Use dedicated upload user with restricted permissions
- Shared directories → Use group permissions with `chmod 775` and proper group membership
