# Quick Reference - Telegram WOL Bot

## Essential Commands

### Telegram Bot Setup
```bash
# Talk to @BotFather
/newbot                    # Create new bot
# Copy the token it gives you

# Get your user ID
# Talk to @userinfobot
/start                     # Shows your user ID
```

### OpenWRT Installation (One-Time)
```bash
# 1. Install packages
opkg update
opkg install curl jq etherwake

# 2. Create directory
mkdir -p /root/wol-bot && cd /root/wol-bot

# 3. Upload/create files:
#    - telegram-wol-bot.sh
#    - config.conf

# 4. Configure
vi config.conf
# Edit: BOT_TOKEN, AUTHORIZED_USERS, device MACs

# 5. Set permissions
chmod +x telegram-wol-bot.sh

# 6. Install service
cp telegram-wol-bot-init /etc/init.d/telegram-wol-bot
chmod +x /etc/init.d/telegram-wol-bot

# 7. Enable and start
/etc/init.d/telegram-wol-bot enable
/etc/init.d/telegram-wol-bot start
```

### Service Management
```bash
/etc/init.d/telegram-wol-bot start      # Start
/etc/init.d/telegram-wol-bot stop       # Stop
/etc/init.d/telegram-wol-bot restart    # Restart
/etc/init.d/telegram-wol-bot status     # Check status
/etc/init.d/telegram-wol-bot enable     # Auto-start on boot
/etc/init.d/telegram-wol-bot disable    # Disable auto-start
```

### Telegram Bot Commands
```
/start      - Show help message
/wake pc    - Wake device named "pc"
/list       - Show all devices
/status     - Bot and router status
```

### Configuration File Format
```bash
# /root/wol-bot/config.conf

BOT_TOKEN="your_token_here"
AUTHORIZED_USERS="123456789 987654321"
DEFAULT_INTERFACE="br-lan"

DEVICE_PC_NAME="Gaming PC"
DEVICE_PC_MAC="AA:BB:CC:DD:EE:FF"
DEVICE_PC_INTERFACE="br-lan"
```

### Finding MAC Addresses
```bash
cat /tmp/dhcp.leases          # DHCP leases
arp -a                        # ARP table
ip neigh                      # Neighbor table
cat /proc/net/arp             # ARP cache
```

### Finding Network Interfaces
```bash
ip link show                  # All interfaces
ifconfig                      # All interfaces (legacy)
ip addr                       # With IP addresses
# Common: br-lan, eth0, eth1, wlan0
```

### Testing WOL Manually
```bash
# Send WOL packet
etherwake -i br-lan AA:BB:CC:DD:EE:FF

# Test with broadcast
etherwake -b AA:BB:CC:DD:EE:FF

# Capture WOL packets (on another device)
tcpdump -i eth0 port 9 or port 7
```

### Troubleshooting Commands
```bash
# Is bot running?
ps | grep telegram-wol-bot
pgrep -f telegram-wol-bot

# Check process details
ps w | grep telegram

# View system logs
logread | grep telegram
logread | tail -50

# Test network
ping api.telegram.org
curl -s https://api.telegram.org/bot<TOKEN>/getMe

# Check required tools
which curl jq etherwake

# Check disk space
df -h

# Check memory
free
top

# Manual test run
/root/wol-bot/telegram-wol-bot.sh
# Press Ctrl+C to stop
```

### Adding New Device
```bash
# 1. Edit config
vi /root/wol-bot/config.conf

# 2. Add device
DEVICE_LAPTOP_NAME="My Laptop"
DEVICE_LAPTOP_MAC="BB:CC:DD:EE:FF:AA"

# 3. Restart bot
/etc/init.d/telegram-wol-bot restart

# 4. Test in Telegram
/list
/wake laptop
```

### Backup Configuration
```bash
# Backup config
cp /root/wol-bot/config.conf /root/wol-bot/config.conf.backup

# Backup to external device
scp /root/wol-bot/config.conf user@pc:/backup/

# Full backup
tar -czf /tmp/wol-bot-backup.tar.gz /root/wol-bot
```

### View Bot Output (Debug)
```bash
# Stop service first
/etc/init.d/telegram-wol-bot stop

# Run manually to see output
/root/wol-bot/telegram-wol-bot.sh

# You'll see:
# - Incoming messages
# - Commands processed
# - WOL packets sent
# - Errors (if any)

# Press Ctrl+C when done
# Restart service
/etc/init.d/telegram-wol-bot start
```

### Enable Debug Logging (Permanent)
```bash
# Edit the script
vi /root/wol-bot/telegram-wol-bot.sh

# Add after "main() {" line:
exec >> /tmp/telegram-wol-bot.log 2>&1
set -x

# Save and restart
/etc/init.d/telegram-wol-bot restart

# View logs
tail -f /tmp/telegram-wol-bot.log
```

### Common Errors & Fixes

**"Unauthorized" in Telegram**
```bash
# Get your user ID from @userinfobot
# Add to config.conf:
AUTHORIZED_USERS="YOUR_USER_ID"
# Restart bot
```

**Bot doesn't start**
```bash
# Check script is executable
chmod +x /root/wol-bot/telegram-wol-bot.sh

# Check config exists
ls -l /root/wol-bot/config.conf

# Check token in config
grep BOT_TOKEN /root/wol-bot/config.conf
```

**WOL doesn't wake device**
```bash
# 1. Check device BIOS has WOL enabled
# 2. Check device is on wired connection (not WiFi)
# 3. Test WOL manually:
etherwake -i br-lan AA:BB:CC:DD:EE:FF

# 4. Verify MAC address
arp -a | grep device-ip

# 5. Check interface
ip link show br-lan
```

**Bot stops after reboot**
```bash
# Check if enabled
ls -l /etc/rc.d/ | grep telegram

# Should see: S99telegram-wol-bot

# If not, enable:
/etc/init.d/telegram-wol-bot enable
```

### Uninstall
```bash
# 1. Stop and disable
/etc/init.d/telegram-wol-bot stop
/etc/init.d/telegram-wol-bot disable

# 2. Remove files
rm -rf /root/wol-bot
rm /etc/init.d/telegram-wol-bot
rm /tmp/telegram-bot-offset

# 3. Optional: remove packages
opkg remove curl jq
# Keep etherwake if needed
```

### Performance Tuning
```bash
# Lower CPU usage (less frequent polling)
vi /root/wol-bot/telegram-wol-bot.sh
# Find: get_updates "$offset" 30
# Change to: get_updates "$offset" 60

# Check current memory usage
ps | grep telegram-wol-bot
# Shows RSS (memory in KB)
```

### Security Checklist
```bash
# 1. Protect config file
chmod 600 /root/wol-bot/config.conf

# 2. Check file permissions
ls -l /root/wol-bot/

# 3. Review authorized users
grep AUTHORIZED_USERS /root/wol-bot/config.conf

# 4. Keep router updated
opkg update && opkg list-upgradable

# 5. Use strong SSH password or keys
```

### File Locations Reference
```
/root/wol-bot/telegram-wol-bot.sh    Main script
/root/wol-bot/config.conf            Configuration
/etc/init.d/telegram-wol-bot         Init service
/tmp/telegram-bot-offset             State file
/tmp/telegram-wol-bot.log            Log (if enabled)
```

### Get Help
```bash
# View this guide
cat /root/wol-bot/QUICK_REFERENCE.txt

# View full guide
cat /root/wol-bot/INSTALLATION_GUIDE.md

# Check OpenWRT docs
# https://openwrt.org/docs/start

# Telegram bot API
# https://core.telegram.org/bots/api
```

---
**💡 Tip: Bookmark this file for quick reference!**
