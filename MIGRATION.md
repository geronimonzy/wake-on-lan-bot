# Migration Guide: OpenWRT to Docker

This guide helps you migrate from the OpenWRT shell script version to the secure Docker version.

## Why Migrate?

### Security Improvements

| Issue | Old Version | New Version |
|-------|-------------|-------------|
| Command Injection | ❌ Vulnerable (eval) | ✅ Fixed (safe parsing) |
| Exposed Secrets | ❌ In repository | ✅ Environment variables |
| Input Validation | ❌ None | ✅ All inputs validated |
| Rate Limiting | ❌ None | ✅ Configurable limits |
| MAC Validation | ❌ None | ✅ Regex validation |
| Info Disclosure | ❌ Logs token/IDs | ✅ Sanitized logs |
| Container Security | ❌ N/A | ✅ Hardened container |

### Feature Improvements

- ✅ Better error handling
- ✅ Automatic restarts
- ✅ Resource limits
- ✅ Structured logging
- ✅ Easy updates
- ✅ Portable deployment

## Prerequisites

### On Your Current System (OpenWRT)

1. **Export your configuration:**
   ```bash
   # SSH into your OpenWRT router
   ssh root@YOUR_ROUTER_IP

   # View your current configuration
   cat /root/wol-bot/config.conf
   ```

2. **Note down:**
   - Your `BOT_TOKEN`
   - Your `AUTHORIZED_USERS`
   - All `DEVICE_*` configurations

3. **Test current setup:**
   ```bash
   # Make sure your devices are configured correctly
   /etc/init.d/telegram-wol-bot status
   ```

### On Your New System (Docker Host)

1. **Install Docker:**
   ```bash
   # Ubuntu/Debian
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh

   # Verify installation
   docker --version
   docker-compose --version
   ```

2. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd wake-on-lan-bot
   ```

## Migration Steps

### Step 1: Export Configuration

On your OpenWRT router:

```bash
# View and copy your bot token
grep BOT_TOKEN /root/wol-bot/config.conf

# View and copy your authorized users
grep AUTHORIZED_USERS /root/wol-bot/config.conf

# View all device configurations
grep ^DEVICE_ /root/wol-bot/config.conf
```

**Example output:**
```bash
BOT_TOKEN="123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
AUTHORIZED_USERS="123456789"
DEVICE_PC_NAME="Gaming PC"
DEVICE_PC_MAC="AA:BB:CC:DD:EE:FF"
DEVICE_PC_INTERFACE="br-lan"
```

### Step 2: Set Up Docker Version

On your Docker host:

```bash
# Run interactive setup
./setup.sh

# Or manual setup:
cp .env.example .env
cp devices.conf.example devices.conf
```

### Step 3: Configure Environment

Edit `.env`:

```bash
nano .env
```

Add your values:
```bash
BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrsTUVwxyz
AUTHORIZED_USERS=123456789
DEFAULT_INTERFACE=  # Leave empty for Docker, or set if needed
```

### Step 4: Configure Devices

Edit `devices.conf`:

```bash
nano devices.conf
```

**Convert from old format to new format:**

Old format (OpenWRT):
```bash
DEVICE_PC_NAME="Gaming PC"
DEVICE_PC_MAC="AA:BB:CC:DD:EE:FF"
DEVICE_PC_INTERFACE="br-lan"
```

New format (Docker) - **Same format!**
```bash
DEVICE_PC_NAME="Gaming PC"
DEVICE_PC_MAC="AA:BB:CC:DD:EE:FF"
DEVICE_PC_INTERFACE="br-lan"  # Optional in Docker
```

You can copy most of your old config directly!

### Step 5: Secure Configuration

```bash
# Set proper permissions
chmod 600 .env
chmod 600 devices.conf

# Verify
ls -la .env devices.conf
# Should show: -rw------- (600)
```

### Step 6: Test Docker Version

```bash
# Build and start
docker-compose up -d

# View logs
docker-compose logs -f

# You should see:
# "Bot is running and ready to receive commands"
```

### Step 7: Test in Telegram

1. Open Telegram and find your bot
2. Send `/start` - should get welcome message
3. Send `/list` - should show your devices
4. Send `/wake PC` - should send WOL packet
5. Verify device wakes up

### Step 8: Stop Old Version

**Only after confirming Docker version works!**

On OpenWRT router:

```bash
# Stop the old bot
/etc/init.d/telegram-wol-bot stop

# Disable from starting on boot
/etc/init.d/telegram-wol-bot disable

# Optional: Remove old files (backup first!)
# cp -r /root/wol-bot /root/wol-bot.backup
# rm -rf /root/wol-bot
# rm /etc/init.d/telegram-wol-bot
```

## Configuration Mapping

### Environment Variables

| Old Location | New Location | Example |
|--------------|--------------|---------|
| `config.conf: BOT_TOKEN` | `.env: BOT_TOKEN` | Same format |
| `config.conf: AUTHORIZED_USERS` | `.env: AUTHORIZED_USERS` | Same format |
| `config.conf: DEFAULT_INTERFACE` | `.env: DEFAULT_INTERFACE` | Same format |

### Device Configuration

| Old Location | New Location | Notes |
|--------------|--------------|-------|
| `config.conf: DEVICE_*` | `devices.conf: DEVICE_*` | **Exact same format** |

### Paths

| Old Path | New Path | Notes |
|----------|----------|-------|
| `/root/wol-bot/config.conf` | `.env` + `devices.conf` | Split into two files |
| `/tmp/telegram-bot-offset` | `/app/state/offset` | Auto-created |
| N/A | `state/` (volume) | Persists across restarts |

## Network Considerations

### OpenWRT Version
- Ran directly on router
- Had direct access to local network
- Interface: typically `br-lan`

### Docker Version
- Uses `network_mode: host`
- Has same network access as host
- Works on any Linux system with Docker
- Interface: depends on your host network setup

**Finding your interface on Docker host:**
```bash
# List network interfaces
ip link show

# Common interfaces:
# - eth0, eno1, enp3s0 (wired)
# - br0, br-lan (bridge)
# - docker0 (Docker bridge - don't use for WOL)
```

**Update devices.conf if interface changed:**
```bash
# Old (on OpenWRT router)
DEVICE_PC_INTERFACE="br-lan"

# New (on Docker host)
DEVICE_PC_INTERFACE="eth0"  # or your actual interface

# Or leave empty to use default
# DEVICE_PC_INTERFACE=""
```

## Troubleshooting Migration

### Issue: Bot not responding after migration

**Check:**
```bash
# 1. Is container running?
docker-compose ps

# 2. Check logs for errors
docker-compose logs --tail=50

# 3. Verify token format
grep BOT_TOKEN .env
# Should be: BOT_TOKEN=123456789:ABCdef...

# 4. Test token manually
curl -s "https://api.telegram.org/bot<YOUR_TOKEN>/getMe"
```

### Issue: WOL not working on Docker host

**Possible causes:**

1. **Wrong network interface:**
   ```bash
   # Find correct interface
   ip link show

   # Update devices.conf
   DEVICE_PC_INTERFACE="eth0"  # your interface
   ```

2. **Docker host not on same network:**
   - WOL requires same Layer 2 network
   - Docker host must be on same LAN as target devices
   - Can't wake devices across router boundaries

3. **Firewall blocking:**
   ```bash
   # Allow WOL broadcasts (if using firewall)
   sudo iptables -A OUTPUT -p udp --dport 9 -j ACCEPT
   ```

4. **Test manually:**
   ```bash
   # From Docker host (not container)
   sudo etherwake -i eth0 AA:BB:CC:DD:EE:FF
   ```

### Issue: "Access denied" messages

**Check:**
```bash
# Verify user ID in .env
grep AUTHORIZED_USERS .env

# Get your user ID from Telegram
# Message @userinfobot and send /start

# Update .env
nano .env
# Set: AUTHORIZED_USERS=123456789

# Restart
docker-compose restart
```

### Issue: Devices not showing in /list

**Check:**
```bash
# 1. Verify devices.conf exists
ls -la devices.conf

# 2. Check for syntax errors
cat devices.conf

# 3. View container logs
docker-compose logs | grep "Loaded"
# Should show: "Loaded X device(s)"

# 4. Validate MAC address format
# Must be: AA:BB:CC:DD:EE:FF (uppercase or lowercase, colons)
```

## Rollback Plan

If you need to rollback to OpenWRT version:

```bash
# On OpenWRT router:

# 1. Restore from backup (if you made one)
cp -r /root/wol-bot.backup /root/wol-bot

# 2. Or re-setup from scratch
mkdir -p /root/wol-bot
# Copy old files back

# 3. Start old version
/etc/init.d/telegram-wol-bot enable
/etc/init.d/telegram-wol-bot start

# On Docker host:

# Stop Docker version
docker-compose down
```

## Post-Migration

### Verify Everything Works

- [ ] Bot responds to /start
- [ ] /list shows all devices
- [ ] /wake sends packets successfully
- [ ] Devices actually wake up
- [ ] Unauthorized users get "Access denied"
- [ ] Logs look clean (no errors)

### Security Checklist

- [ ] `.env` has 600 permissions
- [ ] `devices.conf` has 600 permissions
- [ ] No secrets committed to git
- [ ] Old bot token revoked (if you generated new one)
- [ ] Old configuration backed up securely
- [ ] Docker container is running
- [ ] Resource limits are appropriate

### Optimize

```bash
# Set container to auto-start on boot
docker-compose up -d
# Container restart policy is already set to "unless-stopped"

# Monitor resource usage
docker stats telegram-wol-bot

# Check logs periodically
docker-compose logs --since 24h
```

## Benefits After Migration

### Security
- ✅ All vulnerabilities fixed
- ✅ Secrets properly managed
- ✅ Container isolation
- ✅ Input validation
- ✅ Rate limiting

### Reliability
- ✅ Auto-restart on failure
- ✅ Better error handling
- ✅ Health checks
- ✅ Resource limits prevent runaway processes

### Portability
- ✅ Run on any Docker host (Linux, macOS, Windows with WSL)
- ✅ Easy to move between systems
- ✅ Consistent environment
- ✅ Simple updates

### Maintainability
- ✅ Version controlled
- ✅ Easy to update: `docker-compose pull && docker-compose up -d`
- ✅ Configuration separate from code
- ✅ Better logging

## Getting Help

If you encounter issues:

1. **Check logs:**
   ```bash
   docker-compose logs --tail=100
   ```

2. **Review documentation:**
   - `README_DOCKER.md` - Complete guide
   - `SECURITY.md` - Security info
   - This file - Migration guide

3. **Test configuration:**
   ```bash
   make test
   ```

4. **Verify network:**
   ```bash
   # From Docker host
   ping <device-ip>
   sudo etherwake -i eth0 <mac-address>
   ```

---

**Migration typically takes 10-15 minutes.**
Most of your configuration can be copied directly!