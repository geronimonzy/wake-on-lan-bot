#!/bin/sh
# Telegram Wake-on-LAN Bot for OpenWRT
# Author: Custom Script
# Description: Receives Telegram commands and sends WOL packets

# Configuration file path
CONFIG_FILE="/root/wol-bot/config.conf"
STATE_DIR="/root/wol-bot/state"
STATE_FILE="$STATE_DIR/offset"
RATE_LIMIT_FILE="$STATE_DIR/rate_limit"
SECURITY_LOG="/root/wol-bot/security.log"

# Create state directory if it doesn't exist
mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"

# Load configuration
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found at $CONFIG_FILE"
    exit 1
fi

# Source the config file
. "$CONFIG_FILE"

# Check for required commands
for cmd in curl jq etherwake; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: Required command '$cmd' not found. Please install it."
        exit 1
    fi
done

# Telegram API URLs
API_URL="https://api.telegram.org/bot${BOT_TOKEN}"

# Rate limiting (seconds between WOL commands for same device)
RATE_LIMIT_SECONDS="${RATE_LIMIT_SECONDS:-10}"

# Security logging function
log_security_event() {
    local event="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $event" >> "$SECURITY_LOG"
    chmod 600 "$SECURITY_LOG" 2>/dev/null
}

# Validate device key format (only alphanumeric and underscore, 1-32 chars)
validate_device_key() {
    local key="$1"
    echo "$key" | grep -qE '^[A-Z0-9_]{1,32}$'
    return $?
}

# Validate MAC address format
validate_mac_address() {
    local mac="$1"
    echo "$mac" | grep -qE '^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$'
    return $?
}

# Validate network interface exists
validate_interface() {
    local interface="$1"
    if [ -z "$interface" ]; then
        return 0  # Empty interface is OK (uses default)
    fi
    ip link show "$interface" >/dev/null 2>&1
    return $?
}

# Function to get device MAC address (safe from command injection)
get_device_mac() {
    local device_key="$1"

    # Validate device key format first
    if ! validate_device_key "$device_key"; then
        return 1
    fi

    # Safe variable expansion
    eval "local mac=\${DEVICE_${device_key}_MAC:-}"
    echo "$mac"
}

# Function to get device name (safe from command injection)
get_device_name() {
    local device_key="$1"

    # Validate device key format first
    if ! validate_device_key "$device_key"; then
        return 1
    fi

    # Safe variable expansion
    eval "local name=\${DEVICE_${device_key}_NAME:-}"
    echo "$name"
}

# Function to get device interface (safe from command injection)
get_device_interface() {
    local device_key="$1"

    # Validate device key format first
    if ! validate_device_key "$device_key"; then
        echo "$DEFAULT_INTERFACE"
        return
    fi

    # Safe variable expansion
    eval "local interface=\${DEVICE_${device_key}_INTERFACE:-}"
    echo "${interface:-$DEFAULT_INTERFACE}"
}

# Check if device is rate limited
check_rate_limit() {
    local device_key="$1"
    local current_time=$(date +%s)
    local last_wake_time=0

    # Read last wake time from rate limit file
    if [ -f "$RATE_LIMIT_FILE" ]; then
        last_wake_time=$(grep "^${device_key}:" "$RATE_LIMIT_FILE" 2>/dev/null | cut -d: -f2)
        last_wake_time=${last_wake_time:-0}
    fi

    local time_diff=$((current_time - last_wake_time))

    if [ $time_diff -lt $RATE_LIMIT_SECONDS ]; then
        local wait_time=$((RATE_LIMIT_SECONDS - time_diff))
        return $wait_time
    fi

    return 0
}

# Update rate limit timestamp
update_rate_limit() {
    local device_key="$1"
    local current_time=$(date +%s)

    # Create or update rate limit file
    touch "$RATE_LIMIT_FILE"
    chmod 600 "$RATE_LIMIT_FILE"

    # Remove old entry and add new one
    if [ -f "$RATE_LIMIT_FILE" ]; then
        grep -v "^${device_key}:" "$RATE_LIMIT_FILE" > "${RATE_LIMIT_FILE}.tmp" 2>/dev/null || true
        mv "${RATE_LIMIT_FILE}.tmp" "$RATE_LIMIT_FILE"
    fi

    echo "${device_key}:${current_time}" >> "$RATE_LIMIT_FILE"
}

# Function to check if user is authorized
is_authorized() {
    local user_id="$1"
    for authorized_id in $AUTHORIZED_USERS; do
        if [ "$authorized_id" = "$user_id" ]; then
            return 0
        fi
    done
    log_security_event "UNAUTHORIZED_ACCESS: User ID $user_id attempted access"
    return 1
}

# Function to send Telegram message
send_message() {
    local chat_id="$1"
    local text="$2"
    local parse_mode="${3:-}"
    
    local json_payload
    if [ -n "$parse_mode" ]; then
        json_payload=$(jq -n \
            --arg chat_id "$chat_id" \
            --arg text "$text" \
            --arg parse_mode "$parse_mode" \
            '{chat_id: $chat_id, text: $text, parse_mode: $parse_mode}')
    else
        json_payload=$(jq -n \
            --arg chat_id "$chat_id" \
            --arg text "$text" \
            '{chat_id: $chat_id, text: $text}')
    fi
    
    curl -s -X POST "$API_URL/sendMessage" \
        -H "Content-Type: application/json" \
        -d "$json_payload" >/dev/null 2>&1
}

# Function to send Wake-on-LAN packet
send_wol() {
    local mac="$1"
    local interface="$2"

    # Validate MAC address format
    if ! validate_mac_address "$mac"; then
        log_security_event "INVALID_MAC: Attempted to send WOL to invalid MAC: $mac"
        return 1
    fi

    # Validate interface if specified
    if ! validate_interface "$interface"; then
        log_security_event "INVALID_INTERFACE: Invalid interface specified: $interface"
        return 1
    fi

    if [ -n "$interface" ]; then
        etherwake -i "$interface" "$mac" >/dev/null 2>&1
    else
        etherwake "$mac" >/dev/null 2>&1
    fi

    return $?
}

# Function to list all devices
list_devices() {
    local output="📋 *Available Devices:*\n\n"
    local device_found=0
    
    # Iterate through all DEVICE_ variables
    for var in $(set | grep '^DEVICE_.*_NAME=' | cut -d= -f1); do
        device_found=1
        local key=$(echo "$var" | sed 's/DEVICE_//;s/_NAME//')
        local name=$(get_device_name "$key")
        local mac=$(get_device_mac "$key")
        output="${output}🖥️ *${key}* - ${name}\n   MAC: \`${mac}\`\n\n"
    done
    
    if [ $device_found -eq 0 ]; then
        output="❌ No devices configured."
    else
        output="${output}💡 *Usage:* /wake <device_key>"
    fi
    
    echo "$output"
}

# Function to handle /wake command
handle_wake_command() {
    local chat_id="$1"
    local user_id="$2"
    local device_key="$3"

    # Check authorization
    if ! is_authorized "$user_id"; then
        send_message "$chat_id" "❌ Unauthorized. Access denied."
        return
    fi

    # Check if device key provided
    if [ -z "$device_key" ]; then
        send_message "$chat_id" "⚠️ Please specify a device.\nExample: /wake pc\n\nUse /list to see available devices."
        return
    fi

    # Convert to uppercase for consistency
    device_key=$(echo "$device_key" | tr '[:lower:]' '[:upper:]')

    # Validate device key format (prevent command injection)
    if ! validate_device_key "$device_key"; then
        send_message "$chat_id" "❌ Invalid device name format. Use only letters, numbers, and underscores."
        log_security_event "INVALID_DEVICE_KEY: User $user_id attempted invalid device key: $device_key"
        return
    fi

    # Get device information
    local mac=$(get_device_mac "$device_key")
    local name=$(get_device_name "$device_key")
    local interface=$(get_device_interface "$device_key")

    if [ -z "$mac" ]; then
        send_message "$chat_id" "❌ Device '$device_key' not found.\n\nUse /list to see available devices."
        return
    fi

    # Check rate limiting
    check_rate_limit "$device_key"
    local wait_time=$?
    if [ $wait_time -gt 0 ]; then
        send_message "$chat_id" "⏱ Rate limit: Please wait ${wait_time} seconds before waking ${name} again."
        return
    fi

    # Send WOL packet
    echo "Sending WOL to $name ($mac) on interface $interface"
    if send_wol "$mac" "$interface"; then
        update_rate_limit "$device_key"
        send_message "$chat_id" "✅ Wake-on-LAN packet sent to *${name}*\n\nDevice: \`${device_key}\`\nMAC: \`${mac}\`\nInterface: \`${interface}\`" "Markdown"
        log_security_event "WOL_SENT: User $user_id woke device $device_key ($name)"
        echo "WOL packet sent successfully to $name"
    else
        send_message "$chat_id" "❌ Failed to send WOL packet to ${name}."
        log_security_event "WOL_FAILED: Failed to send WOL to $device_key for user $user_id"
        echo "Failed to send WOL packet to $name"
    fi
}

# Function to handle /list command
handle_list_command() {
    local chat_id="$1"
    local user_id="$2"
    
    # Check authorization
    if ! is_authorized "$user_id"; then
        send_message "$chat_id" "❌ Unauthorized. Access denied."
        return
    fi
    
    local device_list=$(list_devices)
    send_message "$chat_id" "$device_list" "Markdown"
}

# Function to handle /start command
handle_start_command() {
    local chat_id="$1"
    local user_id="$2"

    # Check authorization
    if ! is_authorized "$user_id"; then
        send_message "$chat_id" "❌ Unauthorized. Access denied."
        return
    fi

    local welcome_msg="🤖 *Wake-on-LAN Bot*\n\n"
    welcome_msg="${welcome_msg}Welcome! I can wake up devices on your network.\n\n"
    welcome_msg="${welcome_msg}*Commands:*\n"
    welcome_msg="${welcome_msg}/wake <device> - Wake up a device\n"
    welcome_msg="${welcome_msg}/wakepc - Quick shortcut to wake PC\n"
    welcome_msg="${welcome_msg}/list - Show all devices\n"
    welcome_msg="${welcome_msg}/status - Bot status\n"
    welcome_msg="${welcome_msg}/help - Show this message"

    send_message "$chat_id" "$welcome_msg" "Markdown"
}

# Function to handle /wakepc command (shortcut for /wake pc)
handle_wakepc_command() {
    local chat_id="$1"
    local user_id="$2"

    # Simply call handle_wake_command with "PC" as the device
    handle_wake_command "$chat_id" "$user_id" "PC"
}

# Function to handle /status command
handle_status_command() {
    local chat_id="$1"
    local user_id="$2"

    if ! is_authorized "$user_id"; then
        send_message "$chat_id" "❌ Unauthorized."
        return
    fi

    local uptime=$(uptime | awk '{print $3, $4}' | sed 's/,//')
    local load=$(uptime | awk -F'load average:' '{print $2}')
    local mem_info=$(free | grep Mem | awk '{printf "%.1f%%", ($3/$2) * 100}')

    local status_msg="📊 *Bot Status*\n\n"
    status_msg="${status_msg}✅ Bot is running\n"
    status_msg="${status_msg}⏱ Router uptime: ${uptime}\n"
    status_msg="${status_msg}📈 Load average:${load}\n"
    status_msg="${status_msg}💾 Memory usage: ${mem_info}"

    send_message "$chat_id" "$status_msg" "Markdown"
}

# Function to process incoming messages
process_message() {
    local update="$1"
    
    # Extract message details
    local message_id=$(echo "$update" | jq -r '.message.message_id // .edited_message.message_id // empty')
    local chat_id=$(echo "$update" | jq -r '.message.chat.id // .edited_message.chat.id // empty')
    local user_id=$(echo "$update" | jq -r '.message.from.id // .edited_message.from.id // empty')
    local text=$(echo "$update" | jq -r '.message.text // .edited_message.text // empty')
    local username=$(echo "$update" | jq -r '.message.from.username // .edited_message.from.username // "unknown"')
    
    # Skip if no valid message
    if [ -z "$chat_id" ] || [ -z "$text" ] || [ "$text" = "null" ]; then
        return
    fi
    
    echo "Received message from @$username (ID: $user_id): $text"
    
    # Parse command and arguments
    local command=$(echo "$text" | awk '{print $1}')
    local arg1=$(echo "$text" | awk '{print $2}')
    
    # Handle commands
    case "$command" in
        /start|/help)
            handle_start_command "$chat_id" "$user_id"
            ;;
        /wake)
            handle_wake_command "$chat_id" "$user_id" "$arg1"
            ;;
        /wakepc)
            handle_wakepc_command "$chat_id" "$user_id"
            ;;
        /list)
            handle_list_command "$chat_id" "$user_id"
            ;;
        /status)
            handle_status_command "$chat_id" "$user_id"
            ;;
        *)
            if is_authorized "$user_id"; then
                send_message "$chat_id" "❓ Unknown command. Use /help for available commands."
            fi
            ;;
    esac
}

# Function to get updates from Telegram
get_updates() {
    local offset="${1:-0}"
    local timeout="${2:-30}"
    
    curl -s -X GET "$API_URL/getUpdates" \
        -d "offset=$offset" \
        -d "timeout=$timeout" \
        -d "allowed_updates=[\"message\",\"edited_message\"]"
}

# Main bot loop
main() {
    echo "Starting Telegram WOL Bot..."
    echo "Configuration loaded successfully"
    log_security_event "BOT_STARTED: Wake-on-LAN bot service started"

    # Load last offset
    local offset=0
    if [ -f "$STATE_FILE" ]; then
        offset=$(cat "$STATE_FILE")
    fi

    echo "Bot is running. Press Ctrl+C to stop."
    
    while true; do
        # Get updates from Telegram
        response=$(get_updates "$offset" 30)
        
        # Check if response is valid JSON
        if ! echo "$response" | jq empty 2>/dev/null; then
            echo "Invalid response from Telegram API. Retrying..."
            sleep 5
            continue
        fi
        
        # Check if there are any updates
        local result_count=$(echo "$response" | jq '.result | length')
        
        if [ "$result_count" -gt 0 ]; then
            # Process each update
            echo "$response" | jq -c '.result[]' | while read -r update; do
                # Get update_id for offset
                local update_id=$(echo "$update" | jq -r '.update_id')

                # Process the message
                process_message "$update"

                # Update offset with basic locking
                (
                    flock -x 200
                    offset=$((update_id + 1))
                    echo "$offset" > "$STATE_FILE"
                    chmod 600 "$STATE_FILE"
                ) 200>"${STATE_FILE}.lock"
            done

            # Update offset after processing all messages
            offset=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
        fi
        
        # Small delay to prevent tight loop on errors
        sleep 1
    done
}

# Handle script termination
trap 'echo "Bot stopped."; log_security_event "BOT_STOPPED: Service terminated"; exit 0' INT TERM

# Start the bot
main
