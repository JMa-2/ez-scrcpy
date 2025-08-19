#!/bin/bash

# Absolute path to the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
LAST_IP_FILE="$SCRIPT_DIR/.last_ip"

# Function to start scrcpy in wired mode
start_wired() {
    echo "Disconnecting any existing wireless connections..."
    adb disconnect
    echo "Starting scrcpy in wired mode..."
    scrcpy
}

# Function to start scrcpy in wireless mode
start_wireless() {
    echo "Starting scrcpy in wireless mode..."

    # Check if a last known IP exists
    if [ -f "$LAST_IP_FILE" ]; then
        echo "Do you want to use the last known connection? (y/n)"
        read -r use_last_ip
        if [ "$use_last_ip" = "y" ]; then
            IP_ADDRESS=$(cat "$LAST_IP_FILE")
            adb connect "$IP_ADDRESS":5555
            scrcpy
            exit 0
        fi
    fi

    # Configure a new phone
    echo "Configuring a new phone for wireless connection..."

    # Get the list of connected devices
    mapfile -t DEVICES < <(adb devices | grep -v "List of devices attached" | grep "device" | cut -f1)

    if [ ${#DEVICES[@]} -eq 0 ]; then
        echo "No devices found. Please connect a device and enable USB debugging."
        exit 1
    elif [ ${#DEVICES[@]} -eq 1 ]; then
        DEVICE_ID=${DEVICES[0]}
    else
        echo "Multiple devices found. Please select one:"
        select DEVICE in "${DEVICES[@]}"; do
            if [ -n "$DEVICE" ]; then
                DEVICE_ID=$DEVICE
                break
            else
                echo "Invalid selection. Please try again."
            fi
        done
    fi

    # Get the device's IP addresses
    IP_ADDRESSES=($(adb -s "$DEVICE_ID" shell ip addr show | grep "inet " | grep -v "127.0.0.1" | cut -d' ' -f6 | cut -d/ -f1))

    if [ ${#IP_ADDRESSES[@]} -eq 0 ]; then
        echo "Could not automatically determine the IP address for the selected device."
        echo "Please enter the IP address manually:"
        read -r IP_ADDRESS
    elif [ ${#IP_ADDRESSES[@]} -eq 1 ]; then
        IP_ADDRESS=${IP_ADDRESSES[0]}
    else
        echo "Multiple IP addresses found. Please select one:"
        select IP_ADDRESS in "${IP_ADDRESSES[@]}"; do
            if [ -n "$IP_ADDRESS" ]; then
                break
            else
                echo "Invalid selection. Please try again."
            fi
        done
    fi

    if [ -z "$IP_ADDRESS" ]; then
        echo "No IP address provided. Exiting."
        exit 1
    fi

    echo "Device IP address: $IP_ADDRESS"
    echo "$IP_ADDRESS" > "$LAST_IP_FILE"

    adb -s "$DEVICE_ID" tcpip 5555
    adb connect "$IP_ADDRESS":5555
    scrcpy
}

# Main script logic

echo "Select connection type:"
echo "1. Wired (USB)"
echo "2. Wireless (Wi-Fi)"

read -r choice

case $choice in
    1) start_wired ;;
    2) start_wireless ;;
    *) echo "Invalid choice. Exiting."; exit 1 ;;
esac