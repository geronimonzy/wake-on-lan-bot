# Changelog

## Version 2.0.0 - Docker Edition (2024-12-06)

Complete rewrite with security improvements and Docker deployment.

### Major Changes

#### Security Fixes (15 vulnerabilities resolved)
- ✅ Fixed command injection via eval()
- ✅ Fixed unsafe config file sourcing
- ✅ Moved secrets to environment variables
- ✅ Added input validation for all user inputs
- ✅ Added MAC address format validation
- ✅ Added rate limiting (10s default)
- ✅ Sanitized all log output
- ✅ Secure state file handling

#### New Features
- ✅ Docker containerization
- ✅ Docker Compose orchestration
- ✅ Non-root container execution
- ✅ Read-only filesystem
- ✅ Capability dropping (only NET_RAW)
- ✅ Resource limits (CPU/Memory)
- ✅ Health checks
- ✅ Auto-restart on failure
- ✅ Rate limiting per device/user
- ✅ `/wakepc` shortcut command
- ✅ Interactive setup script
- ✅ Makefile for convenience

#### Documentation
- ✅ Comprehensive Docker setup guide
- ✅ Security documentation with audit
- ✅ Migration guide from OpenWRT
- ✅ Uninstallation guide for old version
- ✅ Quick reference with Makefile

#### Repository Organization
- ✅ Moved old OpenWRT files to `old-openwrt/`
- ✅ New Docker files in root
- ✅ Clear separation of legacy and current versions
- ✅ Improved .gitignore for secrets

### Breaking Changes

- Configuration split into two files:
  - `.env` - Secrets (BOT_TOKEN, AUTHORIZED_USERS)
  - `devices.conf` - Device configurations
- Different deployment method (Docker vs OpenWRT init script)
- Network mode: host (required for WOL)

### Migration Path

See [MIGRATION.md](MIGRATION.md) for complete migration instructions from OpenWRT version.

### File Structure

```
.
├── bot.sh                    # New secure bot script
├── Dockerfile                # Container image definition
├── docker-compose.yml        # Orchestration config
├── .env.example              # Environment template
├── devices.conf.example      # Devices template
├── setup.sh                  # Interactive setup
├── Makefile                  # Convenience commands
├── README.md                 # Main documentation
├── README_DOCKER.md          # Docker guide
├── SECURITY.md               # Security documentation
├── MIGRATION.md              # Migration guide
├── UNINSTALL_OPENWRT.md      # Uninstall guide
└── old-openwrt/              # Legacy files
    ├── telegram-wol-bot.sh   # Old script
    ├── telegram-wol-bot-init # Old init script
    ├── config.conf.example   # Old config
    └── README.md             # Deprecation notice
```

### Security Improvements

**Critical (4 fixed):**
1. No more eval() - Uses safe associative arrays
2. Safe config parsing - Line-by-line validation
3. Environment variables - Secrets not in code
4. Input validation - MAC, interface, user ID validation

**High (2 fixed):**
5. No information disclosure - Sanitized logs
6. Safe device listing - No command injection

**Medium (5 fixed):**
7. Rate limiting - Configurable per device
8. Sanitized output - No token/ID leaks
9. HTTPS enforced - Secure API calls
10. MAC validation - Regex enforcement
11. Secure state files - Proper permissions

**Low (4 fixed):**
12-15. Various minor improvements

### Docker Security

- Non-root user (UID 1000)
- Read-only root filesystem
- tmpfs with security flags
- Only NET_RAW capability
- No exposed ports
- Resource limits enforced
- No new privileges allowed
- Alpine Linux minimal base

### Commands

**New Telegram commands:**
- `/start` - Show help
- `/help` - Show help
- `/wake <device>` - Wake a device
- `/wakepc` - Wake PC (new shortcut)
- `/list` - List devices

**New management commands:**
```bash
make help      # Show all commands
make setup     # Interactive setup
make start     # Start bot
make stop      # Stop bot
make restart   # Restart bot
make logs      # View logs
make status    # Check status
make test      # Test configuration
make clean     # Clean up
```

### Dependencies

**Runtime:**
- Docker
- Docker Compose

**Container packages:**
- Alpine Linux 3.19
- curl
- jq
- etherwake
- bash

### Known Issues

None currently.

### Upgrade Instructions

1. Export configuration from old version
2. Set up Docker environment
3. Test Docker version
4. Remove old version

See [MIGRATION.md](MIGRATION.md) for details.

---

## Version 1.0.0 - OpenWRT Edition (Deprecated)

Original shell script version for OpenWRT routers.

**Status:** Deprecated due to security vulnerabilities.
**Files:** Moved to `old-openwrt/` directory.

### Known Vulnerabilities
- 4 Critical
- 2 High
- 5 Medium
- 4 Low

**Recommendation:** Migrate to Version 2.0 Docker edition.

---

**Current Version:** 2.0.0 (Docker)
**Previous Version:** 1.0.0 (OpenWRT - Deprecated)