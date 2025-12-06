# Telegram Wake-on-LAN Bot Installation Guide for OpenWRT

## Prerequisites

- OpenWRT router with SSH access
- Internet connection
- Basic command line knowledge
- Telegram account

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

**Transfer files to router:**

**Option A: Using SCP (from your computer):**
```bash
scp telegram-wol-bot.sh root@YOUR_ROUTER_IP:/root/wol-bot/
scp config.conf root@YOUR_ROUTER_IP:/root/wol-bot/
```

**Option B: Using vi/nano on router:**
```bash
# Create and edit files directly on router
vi /root/wol-bot/telegram-wol-bot.sh
vi /root/wol-bot/config.conf
```

**Option C: Using wget (if files are hosted):**
```bash
cd /root/wol-bot
wget http://your-server.com/telegram-wol-bot.sh
wget http://your-server.com/config.conf
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
Bot token configured: 123456789:...
Authorized users: 123456789
Bot is running. Press Ctrl+C to stop.
```

**Test in Telegram:**
1. Find your bot in Telegram (search for the username you created)
2. Send `/start` - you should get a welcome message
3. Send `/list` - should show your configured devices
4. Send `/wake pc` - should send WOL packet

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
| `/list` | Show all configured devices | `/list` |
| `/status` | Show bot and router status | `/status` |

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

# Check network connectivity
ping api.telegram.org

# Test curl and jq
curl -s https://api.telegram.org
jq --version

# Check bot logs
logread | tail -20
```

### "Unauthorized" message
- Verify your user ID in config.conf
- Get your ID from @userinfobot
- Restart bot after changing config

### WOL not working
```bash
# Test WOL manually
etherwake -i br-lan AA:BB:CC:DD:EE:FF

# Check if target device supports WOL
# Enable WOL in device BIOS/UEFI settings

# Verify MAC address is correct
arp -a

# Check network interface
ip link show
```

### Bot stops after router reboot
```bash
# Check if service is enabled
ls -l /etc/rc.d/ | grep telegram-wol-bot

# Should show: S99telegram-wol-bot

# If missing, re-enable:
/etc/init.d/telegram-wol-bot enable
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

## Security Best Practices

1. **Keep bot token secret**
   - Never share your bot token
   - Set restrictive permissions: `chmod 600 /root/wol-bot/config.conf`

2. **Limit authorized users**
   - Only add trusted Telegram user IDs
   - Review authorized users regularly

3. **Router security**
   - Use strong SSH password or key authentication
   - Keep OpenWRT updated
   - Disable WAN access to SSH if not needed

4. **Network security**
   - WOL packets stay on local network
   - Bot only communicates with Telegram API
   - Consider firewall rules if exposing services

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

# Remove bot files
rm -rf /root/wol-bot

# Remove state file
rm -f /tmp/telegram-bot-offset

# Optional: Remove packages if not needed elsewhere
opkg remove curl jq
# Keep etherwake if you use it manually
```

---

## Advanced Configuration

### Multiple Network Interfaces

If devices are on different networks:

```bash
DEVICE_PC_INTERFACE="br-lan"
DEVICE_SERVER_INTERFACE="eth1"
DEVICE_GUEST_INTERFACE="br-guest"
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

---

## Support and Resources

- OpenWRT Documentation: https://openwrt.org/docs/start
- Telegram Bot API: https://core.telegram.org/bots/api
- Wake-on-LAN Guide: https://wiki.archlinux.org/title/Wake-on-LAN

---

## File Checklist

After installation, verify these files exist:

- [ ] `/root/wol-bot/telegram-wol-bot.sh` (executable)
- [ ] `/root/wol-bot/config.conf` (configured)
- [ ] `/etc/init.d/telegram-wol-bot` (executable)
- [ ] `/tmp/telegram-bot-offset` (created automatically)

---

**Installation complete! Your bot should now be running and ready to wake up devices.**
