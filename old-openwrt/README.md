# Legacy OpenWRT Version (Deprecated)

⚠️ **This version is deprecated and contains security vulnerabilities.**

## Use Docker Version Instead

Please use the new Docker version instead:
- [Go back to main README](../README.md)
- [Docker setup guide](../README_DOCKER.md)

## What's in This Folder

This folder contains the original OpenWRT shell script version of the bot.

**Files:**
- `telegram-wol-bot.sh` - Original bot script (has vulnerabilities)
- `telegram-wol-bot-init` - OpenWRT init script
- `config.conf.example` - Example configuration
- `README_OPENWRT.md` - Original documentation
- `INSTALLATION_GUIDE.md` - OpenWRT installation guide
- `QUICK_REFERENCE.md` - Quick reference for OpenWRT

## Known Vulnerabilities (15 Total)

### Critical (4)
1. Command injection via eval()
2. Unsafe config file sourcing
3. Exposed secrets in repository
4. Command injection in etherwake calls

### High (2)
5. Exposed user IDs and token in logs
6. Shell command injection in list_devices()

### Medium (5)
7. No rate limiting
8. Information disclosure
9. No HTTPS verification
10. No MAC address validation
11. Insecure state file permissions

### Low (4)
12-15. Various minor issues

**All of these are fixed in Version 2.0 Docker edition.**

## Migration

To migrate from this version to Docker:
1. See [MIGRATION.md](../MIGRATION.md)
2. See [UNINSTALL_OPENWRT.md](../UNINSTALL_OPENWRT.md) to remove this version

## For Historical Reference Only

These files are kept for:
- Historical reference
- Migration assistance
- Understanding what was fixed

**Do not use these files for new installations.**

---

**Use the Docker version:** [Go to main README](../README.md)