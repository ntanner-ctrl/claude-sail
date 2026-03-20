---
name: disk-ops-protection
enabled: true
event: bash
pattern: (dd\s+.*of=/dev/(sd|hd|nvme|disk|loop)|mkfs)
action: block
baseline: true
---

**BLOCKED: Direct disk operation detected**

You're attempting to write directly to a block device or format a filesystem:
- `dd of=/dev/sdX` - Raw disk write (can destroy partitions)
- `mkfs` - Filesystem formatting (erases all data)

These operations are **irreversible** and can destroy data instantly.

**Safe alternatives:**
- For disk imaging: Verify target device with `lsblk` first
- For formatting: Use disk management tools with confirmation dialogs
- For testing: Use loop devices or VM disk images

**If you need to proceed:**
1. Triple-check the target device: `lsblk`, `fdisk -l`
2. Unmount any mounted partitions first
3. Consider creating a backup
4. Temporarily disable this rule with full awareness of the risk
