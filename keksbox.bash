#!/bin/bash
#
# @author: whati001 (Andreas Karner)
# @home: whati001.rehka.dev
#
# @description:
#  Simple low code keksbox application code

# Configuration
readonly SVC_USER="keksbox"
readonly SVC_GROUP="keksbox"
readonly SVC_DIR="/home/keksbox"
readonly TMP_DIR="/tmp"

# Keks data directories
readonly KEKS_DATA_DIR="/opt/keksbox"
readonly KEKS_DATA_DIR_STD="$KEKS_DATA_DIR/standard"
readonly KEKS_DATA_DIR_CUSTOM="$KEKS_DATA_DIR/custom"
readonly KEKS_DATA_DIR_SYSTEM="$KEKS_DATA_DIR/system"
readonly KEKS_LINK_DIR_ACTIVE="$KEKS_DATA_DIR_CUSTOM/active"

# NFC Tag specifications
readonly KEKS_KEY="FFFFFFFF" # TODO: replace with real key (this is the default MIFARE key)
readonly KEKS_DUMP_FILE="$TMP_DIR/dump.mfd"
readonly KEKS_UID_REG="UID.*:( +[0-9A-Za-z]{2}){7}"
readonly KEKS_ATQA_REG="ATQA.*00 +44"
readonly KEKS_SAK_REG="SAK.*00"
readonly KEKS_VALUE_REG="en[0-9]{12}"

# Audio configuration
readonly PLAYER="play" # from sox package
readonly AUDIO_CONNECT="$KEKS_DATA_DIR_SYSTEM/connect.mp3"
readonly AUDIO_DISCONNECT="$KEKS_DATA_DIR_SYSTEM/disconnect.mp3"

# Global variables
ACTIVE_TAG_INFO=""
ACTIVE_KEKS_TAG=""

# Stop song tmux server and remove symlink if it exists
stop_song() {
    tmux kill-server 2>/dev/null
    [[ -L "$KEKS_LINK_DIR_ACTIVE" ]] && rm -f "$KEKS_LINK_DIR_ACTIVE"
}

# Play audio using the specified player and audio file
# This function is called in a new tmux session
# to avoid blocking the main script
play_audio() {
    local AUDIO_FLIE="$1"
    tmux new -d -s audio "$PLAYER \"$AUDIO_FLIE\"" 2>/dev/null
}

# Cleanup function to be called on exit
cleanup() {
    echo "Exiting keksbox service..."
    stop_song
    [[ -f "$KEKS_DUMP_FILE" ]] && rm -f "$KEKS_DUMP_FILE"
    exit 0
}

# Check if same keks tag is connected
same_keks_connected() {
    local CURRENT_INFO
    CURRENT_INFO=$(nfc-list -t 1)
    [[ "$CURRENT_INFO" == "$ACTIVE_TAG_INFO" ]]
}

# Check if the connected tag is a valid keks tag
is_keks_tag() {
    local KEKS_INFO ATQA_COUNT SAK_COUNT KEY_STRING

    KEKS_INFO=$(nfc-list -t 1)
    ATQA_COUNT=$(grep -Ec "$KEKS_ATQA_REG" <<<"$KEKS_INFO")
    SAK_COUNT=$(grep -Ec "$KEKS_SAK_REG" <<<"$KEKS_INFO")

    if ((ATQA_COUNT == 0)) || ((SAK_COUNT == 0)); then
        echo "No valid keks tag found!"
        return 1
    fi

    # Try to read out the tag
    rm -f "$KEKS_DUMP_FILE"
    nfc-mfultralight r "$KEKS_DUMP_FILE" --pw FFFFFFFF

    # Check for magic string
    KEY_STRING=$(strings "$KEKS_DUMP_FILE" | grep -E "$KEKS_VALUE_REG")
    if [[ -z "$KEY_STRING" ]]; then
        echo "No valid keks tag found!"
        return 1
    fi

    # Found valid tag
    ACTIVE_TAG_INFO=$KEKS_INFO
    ACTIVE_KEKS_TAG=$KEY_STRING
    return 0
}

# Start polling of new keks nfc tag
wait_for_new_device() {
    # Reset active tag info
    ACTIVE_TAG_INFO=""
    ACTIVE_KEKS_TAG=""

    echo "Waiting for new keks tag..."
    while true; do
        if ! nfc-poll | grep -q "No target found."; then
            echo "New NFC tag detected!"
            play_audio "$AUDIO_CONNECT"

            if is_keks_tag; then
                sleep 3
                echo "New tag is a keks tag: $ACTIVE_KEKS_TAG"
                return 0
            else
                sleep 3
                echo "Tag is not a keks tag!"
                play_audio "$AUDIO_DISCONNECT"
            fi
        fi
        sleep 1
    done
}

# --- Main script starts here ---

# Register trap for signals
trap cleanup SIGINT SIGTERM EXIT

# Check if the script is run as service user (keksbox)
if [[ "$(id -u)" -ne "$(id -u "$SVC_USER")" ]]; then
    echo "Error: This script must be run as user '$SVC_USER'" >&2
    exit 1
fi

if [[ "$(pwd)" != "$SVC_DIR" ]]; then
    echo "Error: This script must be run from '$SVC_DIR'" >&2
    exit 1
fi

# Create directories if they don't exist
mkdir -p "$KEKS_DATA_DIR_CUSTOM" "$KEKS_DATA_DIR_STD" "$KEKS_DATA_DIR_SYSTEM"

echo "Starting keksbox application"
while true; do
    if ! wait_for_new_device; then
        echo "Error waiting for new tag, retrying..." >&2
        sleep 5
        continue
    fi
    
    # Extract KEKS_DIR from tag name
    KEKS_DIR="${ACTIVE_KEKS_TAG:2:4}"
    echo "Playing kekssong from keks id: $KEKS_DIR"

    # Determine song directory
    if [[ -d "$KEKS_DATA_DIR_CUSTOM/$KEKS_DIR" ]] && [[ -n $(ls "$KEKS_DATA_DIR_CUSTOM/$KEKS_DIR") ]]; then
        echo "Custom song directory found: $KEKS_DATA_DIR_CUSTOM/$KEKS_DIR"
        KEKS_SONG_DIR="$KEKS_DATA_DIR_CUSTOM/$KEKS_DIR"
    else
        KEKS_SONG_DIR="$KEKS_DATA_DIR_STD/$KEKS_DIR"
        [[ -d "$KEKS_SONG_DIR" ]] || {
            echo "Error: Song directory $KEKS_SONG_DIR not found" >&2
            play_audio "$AUDIO_DISCONNECT"
            continue
        }
    fi

    # Play song
    echo "Playing song from directory $KEKS_SONG_DIR"
    play_audio "$KEKS_SONG_DIR/*"

    # Create custom directory and symlink for active song
    KEKS_DATA_DIR_CUSTOM_ACTIVE="$KEKS_DATA_DIR_CUSTOM/$KEKS_DIR"
    mkdir -p "$KEKS_DATA_DIR_CUSTOM_ACTIVE"
    ln -sfn "$KEKS_DATA_DIR_CUSTOM_ACTIVE" "$KEKS_LINK_DIR_ACTIVE"
    echo "Created link for user uploads: $KEKS_LINK_DIR_ACTIVE"

    # Monitor for tag removal
    while same_keks_connected; do
        sleep 1
    done

    echo "NFC tag removed. Stopping playback."
    stop_song
    play_audio "$AUDIO_DISCONNECT"
    # remove symlink of active audio directory
    rm -rf "$KEKS_LINK_DIR_ACTIVE"
done
