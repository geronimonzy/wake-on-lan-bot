#!/bin/bash
# Telegram Wake-on-LAN Bot - Secure Docker Version
# Version: 2.0.0
# Description: Secure Telegram bot for sending WOL packets

set -euo pipefail

# Configuration
readonly CONFIG_FILE="${CONFIG_FILE:-/app/devices.conf}"
readonly STATE_FILE="${STATE_FILE:-/app/state/offset}"
readonly RATE_LIMIT_FILE="/tmp/rate_limit"
readonly RATE_LIMIT_SECONDS="${RATE_LIMIT_SECONDS:-10}"
readonly MAX_RETRIES=3
readonly RETRY_DELAY=5

# Telegram API
readonly API_URL="https://api.telegram.org/bot${BOT_TOKEN}"

# Validate required environment variables
validate_environment() {
    if [[ -z "${BOT_TOKEN:-}" ]]; then
        echo "ERROR: BOT_TOKEN environment variable is required" >&2
        exit 1
    fi

    if [[ -z "${AUTHORIZED_USERS:-}" ]]; then
        echo "ERROR: AUTHORIZED_USERS environment variable is required" >&2
        exit 1
    fi

    if [[ ! "${BOT_TOKEN}" =~ ^[0-9]+:[A-Za-z0-9_-]{35}$ ]]; then
        echo "ERROR: Invalid BOT_TOKEN format" >&2
        exit 1
    fi
}

# Validate MAC address format
validate_mac() {
    local mac="$1"
    if [[ ! "${mac}" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
        return 1
    fi
    return 0
}

# Validate network interface name
validate_interface() {
    local interface="$1"
    # Allow alphanumeric, dash, underscore, and dot
    if [[ ! "${interface}" =~ ^[a-zA-Z0-9._-]{1,15}$ ]]; then
        return 1
    fi
    return 0
}

# Validate user ID
validate_user_id() {
    local user_id="$1"
    if [[ ! "${user_id}" =~ ^[0-9]{1,15}$ ]]; then
        return 1
    fi
    return 0
}

# Validate device key (alphanumeric and underscore only)
validate_device_key() {
    local key="$1"
    if [[ ! "${key}" =~ ^[A-Z0-9_]{1,32}$ ]]; then
        return 1
    fi
    return 0
}

# Associative arrays for device configuration
declare -A DEVICE_NAMES
declare -A DEVICE_MACS
declare -A DEVICE_INTERFACES

# Load and validate device configuration
load_devices() {
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        echo "WARNING: Device configuration file not found at ${CONFIG_FILE}" >&2
        return 0
    fi

    local line_num=0
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        ((line_num++))

        # Skip empty lines and comments
        [[ -z "${key}" || "${key}" =~ ^[[:space:]]*# ]] && continue

        # Remove leading/trailing whitespace
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)

        # Remove quotes from value if present
        value="${value%\"}"
        value="${value#\"}"

        # Parse device configuration
        if [[ "${key}" =~ ^DEVICE_([A-Z0-9_]+)_NAME$ ]]; then
            local device_key="${BASH_REMATCH[1]}"
            if ! validate_device_key "${device_key}"; then
                echo "WARNING: Invalid device key '${device_key}' at line ${line_num}, skipping" >&2
                continue
            fi
            # Sanitize device name (allow alphanumeric, spaces, dashes, and common punctuation)
            if [[ ! "${value}" =~ ^[A-Za-z0-9\ ._-]{1,64}$ ]]; then
                echo "WARNING: Invalid device name at line ${line_num}, skipping" >&2
                continue
            fi
            DEVICE_NAMES["${device_key}"]="${value}"

        elif [[ "${key}" =~ ^DEVICE_([A-Z0-9_]+)_MAC$ ]]; then
            local device_key="${BASH_REMATCH[1]}"
            if ! validate_device_key "${device_key}"; then
                echo "WARNING: Invalid device key '${device_key}' at line ${line_num}, skipping" >&2
                continue
            fi
            if ! validate_mac "${value}"; then
                echo "WARNING: Invalid MAC address '${value}' at line ${line_num}, skipping" >&2
                continue
            fi
            DEVICE_MACS["${device_key}"]="${value}"

        elif [[ "${key}" =~ ^DEVICE_([A-Z0-9_]+)_INTERFACE$ ]]; then
            local device_key="${BASH_REMATCH[1]}"
            if ! validate_device_key "${device_key}"; then
                echo "WARNING: Invalid device key '${device_key}' at line ${line_num}, skipping" >&2
                continue
            fi
            if ! validate_interface "${value}"; then
                echo "WARNING: Invalid interface '${value}' at line ${line_num}, skipping" >&2
                continue
            fi
            DEVICE_INTERFACES["${device_key}"]="${value}"
        fi
    done < "${CONFIG_FILE}"

    echo "Loaded ${#DEVICE_NAMES[@]} device(s)"
}

# Check if user is authorized
is_authorized() {
    local user_id="$1"

    if ! validate_user_id "${user_id}"; then
        return 1
    fi

    # Convert AUTHORIZED_USERS to array and check
    local -a authorized_array
    IFS=' ' read -ra authorized_array <<< "${AUTHORIZED_USERS}"

    for authorized_id in "${authorized_array[@]}"; do
        if [[ "${authorized_id}" == "${user_id}" ]]; then
            return 0
        fi
    done
    return 1
}

# Rate limiting
check_rate_limit() {
    local user_id="$1"
    local device_key="$2"
    local rate_key="${user_id}_${device_key}"
    local current_time=$(date +%s)
    local last_time=0

    if [[ -f "${RATE_LIMIT_FILE}_${rate_key}" ]]; then
        last_time=$(cat "${RATE_LIMIT_FILE}_${rate_key}" 2>/dev/null || echo 0)
    fi

    local time_diff=$((current_time - last_time))

    if [[ ${time_diff} -lt ${RATE_LIMIT_SECONDS} ]]; then
        local wait_time=$((RATE_LIMIT_SECONDS - time_diff))
        return ${wait_time}
    fi

    echo "${current_time}" > "${RATE_LIMIT_FILE}_${rate_key}"
    return 0
}

# Send Telegram message with retry logic
send_message() {
    local chat_id="$1"
    local text="$2"
    local parse_mode="${3:-}"

    # Validate chat_id
    if [[ ! "${chat_id}" =~ ^-?[0-9]{1,20}$ ]]; then
        echo "ERROR: Invalid chat_id" >&2
        return 1
    fi

    # Escape text for JSON (basic escaping)
    text="${text//\\/\\\\}"
    text="${text//\"/\\\"}"
    text="${text//$'\n'/\\n}"

    local json_payload
    if [[ -n "${parse_mode}" ]]; then
        json_payload=$(jq -n \
            --arg chat_id "${chat_id}" \
            --arg text "${text}" \
            --arg parse_mode "${parse_mode}" \
            '{chat_id: $chat_id, text: $text, parse_mode: $parse_mode}')
    else
        json_payload=$(jq -n \
            --arg chat_id "${chat_id}" \
            --arg text "${text}" \
            '{chat_id: $chat_id, text: $text}')
    fi

    local retries=0
    while [[ ${retries} -lt ${MAX_RETRIES} ]]; do
        if curl -s -X POST "${API_URL}/sendMessage" \
            -H "Content-Type: application/json" \
            -d "${json_payload}" \
            --max-time 30 \
            --connect-timeout 10 >/dev/null 2>&1; then
            return 0
        fi
        ((retries++))
        [[ ${retries} -lt ${MAX_RETRIES} ]] && sleep ${RETRY_DELAY}
    done

    echo "ERROR: Failed to send message after ${MAX_RETRIES} retries" >&2
    return 1
}

# Send Wake-on-LAN packet
send_wol() {
    local mac="$1"
    local interface="$2"

    # Final validation before sending
    if ! validate_mac "${mac}"; then
        echo "ERROR: Invalid MAC address: ${mac}" >&2
        return 1
    fi

    if [[ -n "${interface}" ]] && ! validate_interface "${interface}"; then
        echo "ERROR: Invalid interface: ${interface}" >&2
        return 1
    fi

    # Send WOL packet
    if [[ -n "${interface}" ]]; then
        etherwake -i "${interface}" "${mac}" >/dev/null 2>&1
    else
        etherwake "${mac}" >/dev/null 2>&1
    fi

    return $?
}

# List all configured devices
list_devices() {
    if [[ ${#DEVICE_NAMES[@]} -eq 0 ]]; then
        echo "No devices configured."
        return
    fi

    local output="📋 *Available Devices:*\n\n"

    for key in "${!DEVICE_NAMES[@]}"; do
        if [[ -n "${DEVICE_MACS[$key]:-}" ]]; then
            local name="${DEVICE_NAMES[$key]}"
            local mac="${DEVICE_MACS[$key]}"
            output="${output}🖥️ *${key}* - ${name}\n   MAC: \`${mac}\`\n\n"
        fi
    done

    output="${output}💡 *Usage:* /wake <device_key>"
    echo -e "${output}"
}

# Handle /wake command
handle_wake_command() {
    local chat_id="$1"
    local user_id="$2"
    local device_key="$3"

    # Check authorization
    if ! is_authorized "${user_id}"; then
        send_message "${chat_id}" "Access denied."
        echo "Unauthorized access attempt blocked"
        return
    fi

    # Check if device key provided
    if [[ -z "${device_key}" ]]; then
        send_message "${chat_id}" "⚠️ Please specify a device.\nExample: /wake PC\n\nUse /list to see available devices."
        return
    fi

    # Convert to uppercase and validate
    device_key=$(echo "${device_key}" | tr '[:lower:]' '[:upper:]')

    if ! validate_device_key "${device_key}"; then
        send_message "${chat_id}" "Invalid device identifier."
        return
    fi

    # Check if device exists
    if [[ -z "${DEVICE_MACS[$device_key]:-}" ]]; then
        send_message "${chat_id}" "Device '${device_key}' not found.\n\nUse /list to see available devices."
        return
    fi

    # Rate limiting
    if ! check_rate_limit "${user_id}" "${device_key}"; then
        local wait_time=$?
        send_message "${chat_id}" "⏱️ Please wait ${wait_time} seconds before sending another WOL packet to this device."
        return
    fi

    # Get device information
    local mac="${DEVICE_MACS[$device_key]}"
    local name="${DEVICE_NAMES[$device_key]}"
    local interface="${DEVICE_INTERFACES[$device_key]:-${DEFAULT_INTERFACE:-}}"

    # Send WOL packet
    echo "Sending WOL to ${name} (${mac})"
    if send_wol "${mac}" "${interface}"; then
        local msg="✅ Wake-on-LAN packet sent to *${name}*\n\nDevice: \`${device_key}\`\nMAC: \`${mac}\`"
        [[ -n "${interface}" ]] && msg="${msg}\nInterface: \`${interface}\`"
        send_message "${chat_id}" "${msg}" "Markdown"
        echo "WOL packet sent successfully to ${name}"
    else
        send_message "${chat_id}" "Failed to send WOL packet. Please try again."
        echo "Failed to send WOL packet to ${name}"
    fi
}

# Handle /list command
handle_list_command() {
    local chat_id="$1"
    local user_id="$2"

    if ! is_authorized "${user_id}"; then
        send_message "${chat_id}" "Access denied."
        return
    fi

    local device_list=$(list_devices)
    send_message "${chat_id}" "${device_list}" "Markdown"
}

# Handle /start command
handle_start_command() {
    local chat_id="$1"
    local user_id="$2"

    if ! is_authorized "${user_id}"; then
        send_message "${chat_id}" "Access denied."
        return
    fi

    local welcome_msg="🤖 *Wake-on-LAN Bot*\n\n"
    welcome_msg="${welcome_msg}Welcome! I can wake up devices on your network.\n\n"
    welcome_msg="${welcome_msg}*Commands:*\n"
    welcome_msg="${welcome_msg}/wake <device> - Wake up a device\n"
    welcome_msg="${welcome_msg}/wakepc - Wake up PC (shortcut)\n"
    welcome_msg="${welcome_msg}/list - Show all devices\n"
    welcome_msg="${welcome_msg}/help - Show this message"

    send_message "${chat_id}" "${welcome_msg}" "Markdown"
}

# Process incoming message
process_message() {
    local update="$1"

    # Extract message details using jq for safe JSON parsing
    local message_id=$(echo "${update}" | jq -r '.message.message_id // .edited_message.message_id // empty')
    local chat_id=$(echo "${update}" | jq -r '.message.chat.id // .edited_message.chat.id // empty')
    local user_id=$(echo "${update}" | jq -r '.message.from.id // .edited_message.from.id // empty')
    local text=$(echo "${update}" | jq -r '.message.text // .edited_message.text // empty')
    local username=$(echo "${update}" | jq -r '.message.from.username // .edited_message.from.username // "unknown"')

    # Skip if no valid message
    if [[ -z "${chat_id}" || -z "${text}" || "${text}" == "null" ]]; then
        return
    fi

    # Validate extracted values
    if ! validate_user_id "${user_id}"; then
        echo "Invalid user_id received, skipping"
        return
    fi

    echo "Received message from user ID: ${user_id}"

    # Parse command and arguments (limit to first two words)
    local command=$(echo "${text}" | awk '{print $1}' | head -c 20)
    local arg1=$(echo "${text}" | awk '{print $2}' | head -c 32)

    # Handle commands
    case "${command}" in
        /start|/help)
            handle_start_command "${chat_id}" "${user_id}"
            ;;
        /wake)
            handle_wake_command "${chat_id}" "${user_id}" "${arg1}"
            ;;
        /wakepc)
            handle_wake_command "${chat_id}" "${user_id}" "PC"
            ;;
        /list)
            handle_list_command "${chat_id}" "${user_id}"
            ;;
        *)
            if is_authorized "${user_id}"; then
                send_message "${chat_id}" "Unknown command. Use /help for available commands."
            fi
            ;;
    esac
}

# Get updates from Telegram
get_updates() {
    local offset="${1:-0}"
    local timeout="${2:-30}"

    curl -s -X GET "${API_URL}/getUpdates" \
        -d "offset=${offset}" \
        -d "timeout=${timeout}" \
        -d "allowed_updates=[\"message\",\"edited_message\"]" \
        --max-time $((timeout + 10)) \
        --connect-timeout 10
}

# Main bot loop
main() {
    echo "=== Telegram WOL Bot Starting ==="
    echo "Version: 2.0.0"
    echo "Configuration file: ${CONFIG_FILE}"

    # Validate environment
    validate_environment

    # Load device configuration
    load_devices

    # Load last offset
    local offset=0
    if [[ -f "${STATE_FILE}" ]]; then
        offset=$(cat "${STATE_FILE}" 2>/dev/null || echo 0)
    fi

    echo "Bot is running and ready to receive commands"
    echo "=========================================="

    local error_count=0
    local max_errors=10

    while true; do
        # Get updates from Telegram
        local response=$(get_updates "${offset}" 30)

        # Check if response is valid JSON
        if ! echo "${response}" | jq empty 2>/dev/null; then
            ((error_count++))
            echo "WARNING: Invalid response from Telegram API (error ${error_count}/${max_errors})"

            if [[ ${error_count} -ge ${max_errors} ]]; then
                echo "ERROR: Too many consecutive errors, exiting" >&2
                exit 1
            fi

            sleep 5
            continue
        fi

        # Reset error count on successful response
        error_count=0

        # Check if there are any updates
        local result_count=$(echo "${response}" | jq '.result | length')

        if [[ "${result_count}" -gt 0 ]]; then
            # Process each update
            echo "${response}" | jq -c '.result[]' | while read -r update; do
                # Get update_id for offset
                local update_id=$(echo "${update}" | jq -r '.update_id')

                # Process the message
                process_message "${update}"

                # Update offset
                local new_offset=$((update_id + 1))
                echo "${new_offset}" > "${STATE_FILE}"
            done

            # Update offset after processing all messages
            if [[ -f "${STATE_FILE}" ]]; then
                offset=$(cat "${STATE_FILE}")
            fi
        fi

        # Small delay to prevent tight loop
        sleep 1
    done
}

# Handle script termination
cleanup() {
    echo "Bot shutting down gracefully..."
    # Clean up rate limit files
    rm -f /tmp/rate_limit_* 2>/dev/null || true
    exit 0
}

trap cleanup INT TERM

# Start the bot
main