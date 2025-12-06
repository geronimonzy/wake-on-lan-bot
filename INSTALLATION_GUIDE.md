# Telegram Wake-on-LAN Bot Installation Guide for OpenWRT

## Prerequisites

- OpenWRT router with SSH access
- Internet connection (outbound HTTPS access required)
- Basic command line knowledge
- Telegram account
- ~500KB free storage space
- ~2-5MB RAM for bot process

---

## Network Requirements

### Required Ports and Connectivity

**Outbound connections (from router to internet):**
- **HTTPS (port 443)** - Required for Telegram API communication
  - Destination: `api.telegram.org`
  - Protocol: TCP
  - Usually allowed by default on most routers

**Local network (no firewall changes needed):**
- **Wake-on-LAN packets** - Sent only on local network
  - Protocol: UDP port 9 (broadcast)
  - Direction: Local network only
  - No WAN access or port forwarding required

**Inbound connections:**
- **None required** - Bot uses long polling (pulls updates from Telegram)
- No ports need to be opened on firewall
- No port forwarding needed
- Bot does not listen on any ports

### Firewall Configuration

**Most routers (including OpenWRT) require NO firewall changes.**

The bot only needs:
1. ✅ Outbound HTTPS to Telegram API (typically allowed by default)
2. ✅ Local network access for WOL (no firewall involved)

**If you have strict outbound firewall rules**, ensure HTTPS (443) is allowed to:
- `api.telegram.org` (IP addresses may vary)
- Or allow all HTTPS outbound traffic

**Test connectivity:**
```bash
# Test if router can reach Telegram API
ping api.telegram.org

# Test HTTPS connectivity
curl -I https://api.telegram.org

# Should return HTTP 200 or similar response
```

### Network Topology

```
Internet
   │
   │ HTTPS (443)
   ▼
[OpenWRT Router] ◄── Bot runs here
   │
   │ WOL Broadcast (UDP 9)
   │ Local network only
   ▼
[Your Devices]
 ├─ PC
 ├─ NAS
 └─ Servers
```

**Security Notes:**
- ✅ No incoming connections = No attack surface from internet
- ✅ WOL packets never leave local network
- ✅ All communication encrypted (HTTPS to Telegram)
- ✅ No public IP or DNS required
- ✅ Works behind NAT without issues

---

## Step 1: Create Telegram Bot

1. Open Telegram and search for `@BotFather`
2. Send `/newbot` command
3. Follow prompts to choose a name and username for your bot
4. Copy the **API token** (looks like: `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`)
5. Save this token - you'll need it later

**Get Your User ID:**
1. Search for `@userinfobot` on Telegram
2. Send `/start` to get your user ID
3. Save this number (e.g., 123456789)

---

## Step 2: Install Required Packages on OpenWRT

SSH into your router and run:

```bash
# Update package list
opkg update

# Install required packages
opkg install curl jq etherwake

# Optional: Check available space
df -h
```

**Package sizes (approximate):**
- curl: ~200KB
- jq: ~50KB
- etherwake: ~10KB
- Total: ~300KB

---

## Step 3: Create Bot Directory and Files

```bash
# Create directory
mkdir -p /root/wol-bot
cd /root/wol-bot

# Download or create files (see below for file contents)
# You'll need to transfer these files to your router
```

**Files needed:**
1. `telegram-wol-bot.sh` - Main bot script
2. `config.conf` - Bot configuration
3. `telegram-wol-bot-init` - Init/service script

**Transfer files to router:**

**Option A: Using SCP (from your computer):**
```bash
# Transfer all required files
scp telegram-wol-bot.sh root@YOUR_ROUTER_IP:/root/wol-bot/
scp config.conf root@YOUR_ROUTER_IP:/root/wol-bot/
scp telegram-wol-bot-init root@192.168.1.1:/root/wol-bot/



scp telegram-wol-bot.sh config.conf root@192.168.1.1:/root/wol-bot/
```

**Option B: Using vi/nano on router:**
```bash
# Create and edit files directly on router
vi /root/wol-bot/telegram-wol-bot.sh
# Paste or type the script content, save and exit

vi /root/wol-bot/config.conf
# Configure your settings, save and exit

vi /root/wol-bot/telegram-wol-bot-init
# Paste the init script content, save and exit
```

**Option C: Using wget (if files are hosted):**
```bash
cd /root/wol-bot
wget http://your-server.com/telegram-wol-bot.sh
wget http://your-server.com/config.conf
wget http://your-server.com/telegram-wol-bot-init
```

**Option D: Clone from git repository (if available):**
```bash
cd /root
opkg update && opkg install git
git clone https://github.com/yourusername/wake-on-lan-bot.git wol-bot
cd wol-bot
```

---

## Step 4: Configure the Bot

Edit the configuration file:

```bash
vi /root/wol-bot/config.conf
```

**Required changes:**

1. **Set your bot token:**
   ```bash
   BOT_TOKEN="123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
   ```

2. **Set authorized user IDs:**
   ```bash
   AUTHORIZED_USERS="123456789 987654321"
   ```

3. **Configure your devices:**
   ```bash
   DEVICE_PC_NAME="Gaming PC"
   DEVICE_PC_MAC="AA:BB:CC:DD:EE:FF"  # Replace with actual MAC
   DEVICE_PC_INTERFACE="br-lan"
   ```

4. **Optional: Configure rate limiting (v2.0):**
   ```bash
   # Seconds between WOL commands (default: 10)
   RATE_LIMIT_SECONDS=10
   ```

**After editing, secure the config file:**
```bash
chmod 600 /root/wol-bot/config.conf
```

**How to find device MAC addresses:**
```bash
# Check connected devices on your network
cat /tmp/dhcp.leases
# or
arp -a
```

**How to verify network interface:**
```bash
# List network interfaces
ip link show
# Common OpenWRT interface: br-lan
```

---

## Step 5: Set Permissions and Test

```bash
# Make script executable
chmod +x /root/wol-bot/telegram-wol-bot.sh

# Test the bot manually
/root/wol-bot/telegram-wol-bot.sh
```

You should see:
```
Starting Telegram WOL Bot...
Configuration loaded successfully
Bot is running. Press Ctrl+C to stop.
```

**Test in Telegram:**
1. Find your bot in Telegram (search for the username you created)
2. Send `/start` - you should get a welcome message with all commands
3. Send `/list` - should show your configured devices
4. Send `/wake pc` - should send WOL packet
5. Send `/wakepc` - quick shortcut to wake PC
6. Try sending `/wakepc` twice quickly - should see rate limit message

**Check security log:**
```bash
tail -f /root/wol-bot/security.log
# You should see:
# [2025-12-06 10:30:00] BOT_STARTED: Wake-on-LAN bot service started
# [2025-12-06 10:30:15] WOL_SENT: User 123456789 woke device PC (Gaming PC)
```

Press `Ctrl+C` to stop the test.

---

## Step 6: Install as System Service

```bash
# Copy init script
cp /root/wol-bot/telegram-wol-bot-init /etc/init.d/telegram-wol-bot

# Make it executable
chmod +x /etc/init.d/telegram-wol-bot

# Enable service to start on boot
/etc/init.d/telegram-wol-bot enable

# Start the service
/etc/init.d/telegram-wol-bot start
```

---

## Step 7: Verify Service is Running

```bash
# Check service status
/etc/init.d/telegram-wol-bot status

# Check if process is running
ps | grep telegram-wol-bot

# View logs (if using logread)
logread | grep telegram
```

---

## Bot Commands Reference

| Command | Description | Example |
|---------|-------------|---------|
| `/start` or `/help` | Show welcome message and commands | `/start` |
| `/wake <device>` | Wake up a device | `/wake pc` |
| `/wakepc` | 🆕 Quick shortcut to wake PC device | `/wakepc` |
| `/list` | Show all configured devices | `/list` |
| `/status` | Show bot and router status | `/status` |

**New in v2.0:**
- `/wakepc` command for quick PC wake-up
- Rate limiting (default: 10 seconds between WOL commands)
- Security logging to `/root/wol-bot/security.log`
- Input validation to prevent command injection

---

## Device Configuration Guide

### Adding a New Device

1. Edit config file:
   ```bash
   vi /root/wol-bot/config.conf
   ```

2. Add device entry:
   ```bash
   DEVICE_LAPTOP_NAME="My Laptop"
   DEVICE_LAPTOP_MAC="BB:CC:DD:EE:FF:AA"
   DEVICE_LAPTOP_INTERFACE="br-lan"
   ```

3. Restart the bot:
   ```bash
   /etc/init.d/telegram-wol-bot restart
   ```

4. Test with `/wake laptop` in Telegram

### Device Key Naming Rules
- Use UPPERCASE letters (PC, NAS, LAPTOP)
- Can use numbers (PC1, PC2)
- Can use underscores (GAMING_PC)
- Keep it short and memorable

---

## Troubleshooting

### Bot doesn't respond
```bash
# Check if bot is running
ps | grep telegram-wol-bot

# Check network connectivity to Telegram
ping api.telegram.org

# Test HTTPS connectivity (port 443)
curl -I https://api.telegram.org

# Test curl and jq installed
curl --version
jq --version

# Check bot logs
logread | tail -20

# Check security log for errors
tail -20 /root/wol-bot/security.log
```

**If ping works but bot doesn't:**
- Check firewall allows outbound HTTPS (port 443)
- Verify no proxy settings blocking Telegram API
- Test: `curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getMe"`

### Network/Firewall Issues

**Port 443 blocked:**
```bash
# Test if port 443 is accessible
nc -zv api.telegram.org 443

# Check firewall rules
iptables -L -n | grep 443

# Temporarily test without firewall (careful!)
iptables -F OUTPUT
# Then try bot again
# Remember to restore firewall rules!
```

**DNS issues:**
```bash
# Test DNS resolution
nslookup api.telegram.org

# Try alternative DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf
/etc/init.d/telegram-wol-bot restart
```

### "Unauthorized" message
- Verify your user ID in config.conf
- Get your ID from @userinfobot
- Check security log: `grep UNAUTHORIZED /root/wol-bot/security.log`
- Restart bot after changing config

### Rate limit messages
```bash
# This is normal! Rate limiting prevents abuse.
# Wait the specified seconds, or adjust in config.conf:
echo "RATE_LIMIT_SECONDS=5" >> /root/wol-bot/config.conf
/etc/init.d/telegram-wol-bot restart
```

### Invalid device name errors
```bash
# Device keys must be UPPERCASE letters, numbers, underscores only
# Valid: PC, NAS, SERVER_1
# Invalid: pc-main, my.device, server#1

# Check your config:
grep "DEVICE_" /root/wol-bot/config.conf
```

### WOL not working
```bash
# Test WOL manually
etherwake -i br-lan AA:BB:CC:DD:EE:FF

# Check if target device supports WOL
# Enable WOL in device BIOS/UEFI settings

# Verify MAC address is correct
arp -a
cat /tmp/dhcp.leases

# Check network interface exists
ip link show

# Verify device is on same network segment
# WOL doesn't work across different VLANs/subnets
```

### Bot stops after router reboot
```bash
# Check if service is enabled
ls -l /etc/rc.d/ | grep telegram-wol-bot

# Should show: S99telegram-wol-bot

# If missing, re-enable:
/etc/init.d/telegram-wol-bot enable

# Test by rebooting:
reboot
# Wait for router to come back up, then:
/etc/init.d/telegram-wol-bot status
```

### High memory usage
```bash
# Check memory
free
top

# If needed, reduce polling timeout in script
# Edit telegram-wol-bot.sh, find:
# get_updates "$offset" 30
# Change 30 to 60 for less frequent checks
```

### Security log issues
```bash
# Log file too large
du -h /root/wol-bot/security.log

# Manually rotate log
mv /root/wol-bot/security.log /root/wol-bot/security.log.old
touch /root/wol-bot/security.log
chmod 600 /root/wol-bot/security.log
/etc/init.d/telegram-wol-bot restart

# Set up automatic rotation (see Advanced Configuration)
```

### State file corruption
```bash
# If bot behaves strangely, reset state:
/etc/init.d/telegram-wol-bot stop
rm -rf /root/wol-bot/state
/etc/init.d/telegram-wol-bot start

# State will be recreated automatically
```

---

## Service Management Commands

```bash
# Start bot
/etc/init.d/telegram-wol-bot start

# Stop bot
/etc/init.d/telegram-wol-bot stop

# Restart bot (after config changes)
/etc/init.d/telegram-wol-bot restart

# Check status
/etc/init.d/telegram-wol-bot status

# Enable on boot
/etc/init.d/telegram-wol-bot enable

# Disable on boot
/etc/init.d/telegram-wol-bot disable
```

---

## Security Best Practices (v2.0 Enhanced)

### 🔒 Critical Security Steps

1. **Secure configuration files**
   ```bash
   chmod 600 /root/wol-bot/config.conf
   chmod 600 /root/wol-bot/devices.conf  # if using devices.conf
   chmod 700 /root/wol-bot/state
   chmod 600 /root/wol-bot/security.log
   ```

2. **Keep bot token secret**
   - Never share your bot token
   - Never commit config files to version control
   - Rotate token if accidentally exposed

3. **Limit authorized users**
   - Only add trusted Telegram user IDs
   - Review authorized users regularly
   - Monitor security log for unauthorized access attempts

4. **Router security**
   - Use strong SSH password or key authentication
   - Keep OpenWRT updated
   - Disable WAN access to SSH if not needed
   - Use SSH key authentication instead of passwords

5. **Network security**
   - WOL packets stay on local network (no WAN exposure)
   - Bot only communicates with Telegram API (HTTPS)
   - No incoming ports opened = no attack surface
   - All communication encrypted

### 🛡️ v2.0 Security Features

The bot now includes enterprise-grade security:

- ✅ **Input Validation** - All device keys validated with regex
- ✅ **MAC Address Validation** - MAC addresses checked before WOL
- ✅ **Interface Validation** - Network interfaces verified
- ✅ **Rate Limiting** - Prevents abuse (default: 10 seconds)
- ✅ **Security Logging** - Complete audit trail
- ✅ **File Locking** - Prevents race conditions
- ✅ **Command Injection Protection** - Safe variable handling
- ✅ **No Information Disclosure** - Error messages sanitized

### 📊 Monitor Security Events

```bash
# View real-time security events
tail -f /root/wol-bot/security.log

# Check for unauthorized access attempts
grep "UNAUTHORIZED" /root/wol-bot/security.log

# View all WOL commands
grep "WOL_SENT" /root/wol-bot/security.log

# View failed WOL attempts
grep "WOL_FAILED" /root/wol-bot/security.log
```

**For complete security details, see [SECURITY_FIXES.md](SECURITY_FIXES.md)**

---

## Backup Your Configuration

```bash
# Backup config file
cp /root/wol-bot/config.conf /root/wol-bot/config.conf.backup

# Or backup to external storage
scp /root/wol-bot/config.conf user@your-pc:/backup/
```

---

## Uninstallation

```bash
# Stop and disable service
/etc/init.d/telegram-wol-bot stop
/etc/init.d/telegram-wol-bot disable

# Remove service file
rm /etc/init.d/telegram-wol-bot

# Remove bot files (includes security.log and state directory)
rm -rf /root/wol-bot

# Clean up old state file location (if upgrading from v1.0)
rm -f /tmp/telegram-bot-offset

# Optional: Remove packages if not needed elsewhere
opkg remove curl jq
# Keep etherwake if you use it manually
```

**Note:** Removing `/root/wol-bot` will delete:
- Configuration files
- Security logs (backup first if needed!)
- State files
- Rate limit data

---

## Advanced Configuration

### Rate Limiting Configuration

Customize rate limiting in `config.conf`:

```bash
# Allow WOL every 15 seconds instead of 10
RATE_LIMIT_SECONDS=15

# Disable rate limiting (not recommended for security)
RATE_LIMIT_SECONDS=0

# Very strict: only allow WOL every 30 seconds
RATE_LIMIT_SECONDS=30
```

### Multiple Network Interfaces

If devices are on different networks:

```bash
DEVICE_PC_INTERFACE="br-lan"
DEVICE_SERVER_INTERFACE="eth1"
DEVICE_GUEST_INTERFACE="br-guest"
```

### Security Log Rotation

Prevent security log from growing too large:

```bash
# Create logrotate config
cat > /etc/logrotate.d/telegram-wol-bot << 'EOF'
/root/wol-bot/security.log {
    size 1M
    rotate 5
    compress
    missingok
    notifempty
}
EOF
```

### Custom Timeout Values

Edit the main script to adjust polling interval:
```bash
# In telegram-wol-bot.sh, find:
response=$(get_updates "$offset" 30)
# Change 30 to desired seconds (10-60 recommended)
```

### Enable Debug Logging

Add logging to script:
```bash
# Add at top of main() function:
exec >> /tmp/telegram-wol-bot.log 2>&1
set -x
```

### Separate Devices Configuration File

Use the optional `devices.conf` file for cleaner separation:

1. Create `/root/wol-bot/devices.conf`:
   ```bash
   # Device definitions
   DEVICE_PC_NAME="Gaming PC"
   DEVICE_PC_MAC="AA:BB:CC:DD:EE:FF"
   DEVICE_PC_INTERFACE="br-lan"
   ```

2. Source it in `config.conf`:
   ```bash
   # Load devices from separate file
   . /root/wol-bot/devices.conf
   ```

3. Secure permissions:
   ```bash
   chmod 600 /root/wol-bot/devices.conf
   ```

---

## Support and Resources

- **Documentation:**
  - [README_OPENWRT.md](README_OPENWRT.md) - Main documentation
  - [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Command reference
  - [SECURITY_FIXES.md](SECURITY_FIXES.md) - Security audit
  - [SECURITY_SUMMARY.md](SECURITY_SUMMARY.md) - Security overview

- **External Resources:**
  - OpenWRT Documentation: https://openwrt.org/docs/start
  - Telegram Bot API: https://core.telegram.org/bots/api
  - Wake-on-LAN Guide: https://wiki.archlinux.org/title/Wake-on-LAN

---

## File Checklist

After installation, verify these files exist:

**Required files:**
- [ ] `/root/wol-bot/telegram-wol-bot.sh` (executable, chmod 750)
- [ ] `/root/wol-bot/config.conf` (configured, chmod 600)
- [ ] `/etc/init.d/telegram-wol-bot` (executable, chmod 755)

**Auto-created files (v2.0):**
- [ ] `/root/wol-bot/state/` (directory, chmod 700)
- [ ] `/root/wol-bot/state/offset` (auto-created, chmod 600)
- [ ] `/root/wol-bot/state/rate_limit` (auto-created, chmod 600)
- [ ] `/root/wol-bot/state/offset.lock` (auto-created)
- [ ] `/root/wol-bot/security.log` (auto-created, chmod 600)

**Optional files:**
- [ ] `/root/wol-bot/devices.conf` (if using separate device config)

**Verification commands:**
```bash
# Check file permissions
ls -la /root/wol-bot/
ls -la /root/wol-bot/state/

# Verify bot is running
ps | grep telegram-wol-bot

# Check security log exists
test -f /root/wol-bot/security.log && echo "Security log exists" || echo "Security log missing"

# View recent security events
tail -n 10 /root/wol-bot/security.log
```

---

## Quick Test Checklist

After installation, test these features:

1. **Basic functionality:**
   - [ ] `/start` - Shows welcome message
   - [ ] `/list` - Lists all devices
   - [ ] `/wake pc` - Sends WOL packet
   - [ ] `/wakepc` - Quick PC wake shortcut
   - [ ] `/status` - Shows bot status

2. **Security features (v2.0):**
   - [ ] Send `/wakepc` twice quickly - Should see rate limit message
   - [ ] Check security log - `tail /root/wol-bot/security.log`
   - [ ] Try invalid device name - Should reject with validation error
   - [ ] Unauthorized user test - Should be denied

3. **Service persistence:**
   - [ ] Restart router - Bot should auto-start
   - [ ] Check after reboot - `/etc/init.d/telegram-wol-bot status`

---

**🎉 Installation complete! Your bot is now running with enterprise-grade security.**

**Next steps:**
- Monitor security log: `tail -f /root/wol-bot/security.log`
- Review [SECURITY_FIXES.md](SECURITY_FIXES.md) for complete security details
- Set up log rotation if running long-term
