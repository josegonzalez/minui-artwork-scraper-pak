#!/bin/sh
set -x
PAK_DIR="$(dirname "$0")"
PAK_NAME="$(basename "$PAK_DIR")"
PAK_NAME="${PAK_NAME%.*}"

rm -f "$LOGS_PATH/$PAK_NAME.txt"
exec >>"$LOGS_PATH/$PAK_NAME.txt"
exec 2>&1

echo "$0" "$@"
cd "$PAK_DIR" || exit 1
mkdir -p "$USERDATA_PATH/$PAK_NAME"

architecture=arm
if uname -m | grep -q '64'; then
    architecture=arm64
fi

export PATH="$PAK_DIR/bin/$architecture:$PAK_DIR/bin/$PLATFORM:$PAK_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$PAK_DIR/lib/$architecture:$PAK_DIR/lib/$PLATFORM:$PAK_DIR/lib:$LD_LIBRARY_PATH"
export IMAGE_MATCHER_URL="https://matching-images-is.bittersweet.rip"
export SCREENSCRAPER_API_URL="https://api.screenscraper.fr/api2"
export MINUI_IMAGE_WIDTH=300

# App Settings Management
SETTINGS_FILE="$USERDATA_PATH/$PAK_NAME/settings.json"

load_settings() {
    if [ -f "$SETTINGS_FILE" ]; then
        export ARTWORK_PROVIDER=$(jq -r '.provider // "bittersweet"' "$SETTINGS_FILE")
    else
        export ARTWORK_PROVIDER="bittersweet"
        # Create default settings file
        mkdir -p "$(dirname "$SETTINGS_FILE")"
        echo '{"provider": "bittersweet"}' > "$SETTINGS_FILE"
    fi
}

save_settings() {
    local provider="$1"
    mkdir -p "$(dirname "$SETTINGS_FILE")"
    jq -n --arg p "$provider" '{"provider": $p}' > "$SETTINGS_FILE"
    export ARTWORK_PROVIDER="$provider"
}

load_settings

# ScreenScraper configuration
SCREENSCRAPER_CONF="$PAK_DIR/screenscraper.conf"
SYSTEM_CACHE_FILE="$SDCARD_PATH/Artwork/.cache/systems.json"

# ScreenScraper configuration management
load_screenscraper_config() {
    if [ ! -f "$SCREENSCRAPER_CONF" ]; then
        show_message "ScreenScraper configuration file not found" 4
        return 1
    fi
    
    # Check if required credentials are present
    if ! jq -e '.devid and .devpassword' "$SCREENSCRAPER_CONF" >/dev/null 2>&1; then
        show_message "ScreenScraper configuration missing required credentials" 4
        return 1
    fi
    
    export SCREENSCRAPER_DEVID="$(jq -r '.devid' "$SCREENSCRAPER_CONF")"
    export SCREENSCRAPER_DEVPASSWORD="$(jq -r '.devpassword' "$SCREENSCRAPER_CONF")"
    export SCREENSCRAPER_SOFTNAME="$(jq -r '.softname' "$SCREENSCRAPER_CONF")"
    export SCREENSCRAPER_SSID="$(jq -r '.ssid // empty' "$SCREENSCRAPER_CONF")"
    export SCREENSCRAPER_SSPASSWORD="$(jq -r '.sspassword // empty' "$SCREENSCRAPER_CONF")"
    export SCREENSCRAPER_OUTPUT="$(jq -r '.output_format // "json"' "$SCREENSCRAPER_CONF")"
    export SCREENSCRAPER_MAX_RETRIES="$(jq -r '.max_retries // 3' "$SCREENSCRAPER_CONF")"
    export SCREENSCRAPER_RETRY_DELAY="$(jq -r '.retry_delay // 2' "$SCREENSCRAPER_CONF")"
    
    # Load artwork type fallback arrays as JSON strings
    export SCREENSCRAPER_SNAP_MEDIA_ARRAY="$(jq -c '.artwork_types.snap // ["screenshot"]' "$SCREENSCRAPER_CONF")"
    export SCREENSCRAPER_TITLE_MEDIA_ARRAY="$(jq -c '.artwork_types.title // ["title"]' "$SCREENSCRAPER_CONF")"
    export SCREENSCRAPER_BOXART_MEDIA_ARRAY="$(jq -c '.artwork_types.boxart // ["box-2D-wor"]' "$SCREENSCRAPER_CONF")"
    
    return 0
}

build_screenscraper_url() {
    local endpoint="$1"
    local params="$2"
    
    # URL encode parameters to handle spaces and special characters
    local encoded_softname
    encoded_softname=$(echo "$SCREENSCRAPER_SOFTNAME" | sed 's/ /%20/g')
    
    local base_url="$SCREENSCRAPER_API_URL/$endpoint?devid=$SCREENSCRAPER_DEVID&devpassword=$SCREENSCRAPER_DEVPASSWORD&softname=$encoded_softname&output=$SCREENSCRAPER_OUTPUT"
    
    if [ -n "$SCREENSCRAPER_SSID" ]; then
        base_url="$base_url&ssid=$SCREENSCRAPER_SSID"
    fi
    
    if [ -n "$SCREENSCRAPER_SSPASSWORD" ]; then
        base_url="$base_url&sspassword=$SCREENSCRAPER_SSPASSWORD"
    fi
    
    if [ -n "$params" ]; then
        base_url="$base_url&$params"
    fi
    
    echo "$base_url"
}

screenscraper_curl() {
    local url="$1"
    local max_retries="$SCREENSCRAPER_MAX_RETRIES"
    local retry_delay="$SCREENSCRAPER_RETRY_DELAY"
    local attempt=1

    while [ $attempt -le $max_retries ]; do
        local response_file
        response_file=$(mktemp)
        local http_code
        http_code=$(curl -k -s -o "$response_file" -w "%{http_code}" -X GET -H "User-Agent: MinUI-Artwork-Scraper/1.0" "$url")

        case "$http_code" in
            200)
                cat "$response_file"
                rm -f "$response_file"
                return 0
                ;;
            000)
                # Network connection error
                if [ $attempt -lt $max_retries ]; then
                    show_message "Network error (HTTP 000), retrying... (attempt $attempt/$max_retries)" 2
                    sleep $retry_delay
                    retry_delay=$((retry_delay * 2))
                else
                    show_message "Network connection failed. Please check your internet connection." 4
                    rm -f "$response_file"
                    return 1
                fi
                ;;
            429|430|431)
                # Rate limiting - wait and retry
                if [ $attempt -lt $max_retries ]; then
                    show_message "Rate limited, waiting $retry_delay seconds... (attempt $attempt/$max_retries)" 2
                    sleep $retry_delay
                    retry_delay=$((retry_delay * 2))
                else
                    show_message "Rate limit exceeded, please try again later" 4
                    rm -f "$response_file"
                    return 1
                fi
                ;;
            403)
                show_message "Invalid ScreenScraper credentials" 4
                rm -f "$response_file"
                return 1
                ;;
            404)
                show_message "Resource not found" 2
                rm -f "$response_file"
                return 1
                ;;
            423)
                show_message "ScreenScraper API is temporarily unavailable" 4
                rm -f "$response_file"
                return 1
                ;;
            5*)
                # Server error - wait and retry
                if [ $attempt -lt $max_retries ]; then
                    show_message "Server error, retrying... (attempt $attempt/$max_retries)" 2
                    sleep $retry_delay
                else
                    show_message "Server error, please try again later" 4
                    rm -f "$response_file"
                    return 1
                fi
                ;;
            *)
                # Other error
                show_message "API error: HTTP $http_code - URL: $url" 2
                rm -f "$response_file"
                return 1
                ;;
        esac

        rm -f "$response_file"
        attempt=$((attempt + 1))
    done

    return 1
}

populate_emus_list() {
    ls -A "$SDCARD_PATH/Roms" | sort >/tmp/emus

    touch /tmp/emus.list
    while read -r folder; do
        if [ -n "$(ls -A "$SDCARD_PATH/Roms/$folder" 2>/dev/null | grep -v '^\.' | grep -v '\.txt$')" ]; then
            basename "$folder" >>/tmp/emus.list
        fi
    done </tmp/emus
    sed -i '/^[.]/d; /^APPS/d; /^PORTS/d' /tmp/emus.list

    # Add Cache Management and Settings options at the top
    echo "Settings" >/tmp/emus.list.tmp
    echo "Cache Management" >>/tmp/emus.list.tmp
    cat /tmp/emus.list >>/tmp/emus.list.tmp
    mv /tmp/emus.list.tmp /tmp/emus.list
}

main_screen() {
    minui_list_file="/tmp/minui-list"
    rm -f "$minui_list_file" "/tmp/minui-output"
    touch "$minui_list_file"

    if [ ! -f "/tmp/emus.list" ]; then
        show_message "Populating emus list" forever
        populate_emus_list
    fi

    killall minui-presenter >/dev/null 2>&1 || true
    minui-list --disable-auto-sleep --item-key "folders" --file "/tmp/emus.list" --format text --cancel-text "EXIT" --title "Artwork Scraper" --write-location /tmp/minui-output --write-value state
}

action_menu() {
    ROM_FOLDER="$1"

    rm -f /tmp/action.list /tmp/action-output
    echo "Download Boxart as Artwork" >>/tmp/action.list
    echo "Download Title as Artwork" >>/tmp/action.list
    echo "Download Screenshot as Artwork" >>/tmp/action.list
    echo "Delete Artwork" >>/tmp/action.list

    killall minui-presenter >/dev/null 2>&1 || true
    minui-list --disable-auto-sleep --item-key "actions" --file "/tmp/action.list" --format text --cancel-text "BACK" --title "$ROM_FOLDER" --write-location /tmp/action-output --write-value state

    if [ $? -ne 0 ]; then
        return 1
    fi

    output="$(cat /tmp/action-output)"
    selected_index="$(echo "$output" | jq -r '.selected')"
    selection="$(echo "$output" | jq -r ".actions[$selected_index].name")"

    echo "$selection"
    return 0
}

delete_menu() {
    ROM_FOLDER="$1"

    rm -f /tmp/delete.list /tmp/delete-output
    echo "Delete All Images" >/tmp/delete.list
    echo "Delete Individual Images" >>/tmp/delete.list

    killall minui-presenter >/dev/null 2>&1 || true
    minui-list --disable-auto-sleep --item-key "options" --file "/tmp/delete.list" --format text --cancel-text "BACK" --title "Delete $ROM_FOLDER Artwork" --write-location /tmp/delete-output --write-value state

    if [ $? -ne 0 ]; then
        return 1
    fi

    output="$(cat /tmp/delete-output)"
    selected_index="$(echo "$output" | jq -r '.selected')"
    selection="$(echo "$output" | jq -r ".options[$selected_index].name")"

    echo "$selection"
    return 0
}

fetch_artwork() {
    ROM_FOLDER="$1" ART_TYPE="${2:-snap}" REFRESH_CACHE="${3:-false}"
    
    if [ "$ARTWORK_PROVIDER" = "screenscraper" ]; then
        fetch_artwork_screenscraper "$ROM_FOLDER" "$ART_TYPE" "$REFRESH_CACHE"
    else
        fetch_artwork_bittersweet "$ROM_FOLDER" "$ART_TYPE" "$REFRESH_CACHE"
    fi
}

fetch_artwork_bittersweet() {
    ROM_FOLDER="$1" ART_TYPE="${2:-snap}" REFRESH_CACHE="${3:-false}"
    rom_file="$SDCARD_PATH/Artwork/.cache/matches/$ROM_FOLDER.in.txt"
    artwork_file="$SDCARD_PATH/Artwork/.cache/matches/$ROM_FOLDER.$ART_TYPE.out.txt"
    emu_name="$(get_emu_name "$ROM_FOLDER")"

    mkdir -p "$SDCARD_PATH/Artwork/.cache/matches"
    mkdir -p "$SDCARD_PATH/Artwork/$ROM_FOLDER/$ART_TYPE"
    if [ "$REFRESH_CACHE" = "true" ] || [ ! -f "$artwork_file" ] || [ ! -s "$artwork_file" ]; then
        ls -A "$SDCARD_PATH/Roms/$ROM_FOLDER" >"$rom_file"

        curl -fksSL -X POST -H "Content-Type: text/plain" \
            --data-binary "@$rom_file" \
            -o "$artwork_file" \
            "$IMAGE_MATCHER_URL/matches/$emu_name/$ART_TYPE"
        if [ $? -ne 0 ]; then
            return 1
        fi

        sync
    fi

    # add a newline to the end of this for proper parsing
    echo >>"$artwork_file"

    download_count=0
    total_count="$(wc -l <"$artwork_file")"
    rom_count="$(wc -l <"$rom_file")"
    show_message "Ensuring artwork is cached" forever
    while read -r line; do
        # if the line is empty, skip it
        if [ -z "$line" ]; then
            continue
        fi

        rom_name="$(echo "$line" | cut -f1)"
        artwork_url="$(echo "$line" | cut -f2)"

        if [ -f "$SDCARD_PATH/Artwork/$ROM_FOLDER/$ART_TYPE/$rom_name.png" ] && [ "$REFRESH_CACHE" = "false" ]; then
            download_count=$((download_count + 1))
            continue
        fi

        curl -fksSL -X GET -H "Content-Type: text/plain" \
            -o "$SDCARD_PATH/Artwork/$ROM_FOLDER/$ART_TYPE/$rom_name.png" \
            "$artwork_url"
        if [ $? -ne 0 ]; then
            show_message "Failed to download $rom_name image" forever
            continue
        fi

        download_count=$((download_count + 1))
        iteration=$((download_count % 10))
        if [ "$iteration" -eq 0 ]; then
            show_message "Downloaded $download_count/$total_count" forever
        fi
    done <"$artwork_file"

    sync

    is_nextui=false
    image_folder="res"
    base_directory="$SDCARD_PATH/Roms/$ROM_FOLDER"
    if [ "$IS_NEXT" = "true" ] || [ "$IS_NEXT" = "yes" ]; then
        is_nextui=true
        image_folder="media"
    elif [ -f "$SHARED_USERDATA_PATH/minuisettings.txt" ]; then
        is_nextui=true
        image_folder="media"
    fi

    show_message "Copying $download_count images to '$ROM_FOLDER' .$image_folder folder" forever
    while read -r line; do
        if [ -z "$line" ]; then
            continue
        fi

        rom_name="$(echo "$line" | cut -f1)"
        filename="${rom_name%.*}"
        if [ -z "$rom_name" ] || [ -z "$filename" ]; then
            continue
        fi

        mkdir -p "$base_directory/.$image_folder/"
        if [ "$is_nextui" = "true" ]; then
            cp -f "$SDCARD_PATH/Artwork/$ROM_FOLDER/$ART_TYPE/$rom_name.png" "$base_directory/.$image_folder/$filename.png"
        else
            gm convert "$SDCARD_PATH/Artwork/$ROM_FOLDER/$ART_TYPE/$rom_name.png" -resize "$MINUI_IMAGE_WIDTH" "$base_directory/.$image_folder/$rom_name.png"
        fi

        echo "$rom_name"
    done <"$artwork_file"

    sync

    show_message "Copied $download_count images for $rom_count roms" 4
}

fetch_artwork_screenscraper() {
    ROM_FOLDER="$1" ART_TYPE="${2:-snap}" REFRESH_CACHE="${3:-false}"
    rom_file="$SDCARD_PATH/Artwork/.cache/matches/$ROM_FOLDER.in.txt"
    artwork_file="$SDCARD_PATH/Artwork/.cache/matches/$ROM_FOLDER.$ART_TYPE.out.txt"
    emu_name="$(get_emu_name "$ROM_FOLDER")"

    # Load ScreenScraper configuration
    if ! load_screenscraper_config; then
        show_message "ScreenScraper configuration not loaded" 4
        return 1
    fi

    mkdir -p "$SDCARD_PATH/Artwork/.cache/matches"
    mkdir -p "$SDCARD_PATH/Artwork/$ROM_FOLDER/$ART_TYPE"
    # Cache for jeuInfos JSON per ROM (persist between runs)
    mkdir -p "$SDCARD_PATH/Artwork/.cache/jeuInfos"

    # Find system ID
    show_message "Finding system for $emu_name" forever
    local system_id
    system_id=$(getSystemID "$emu_name")
    if [ $? -ne 0 ]; then
        show_message "Could not find system ID for $emu_name" 4
        return 1
    fi

    # Get media type fallback array for artwork
    local media_type_array
    # Always parse as array for fallback logic
    if [ "$ART_TYPE" = "snap" ]; then
        media_type_array=$(echo "$SCREENSCRAPER_SNAP_MEDIA_ARRAY" | jq -r '.')
    elif [ "$ART_TYPE" = "title" ]; then
        media_type_array=$(echo "$SCREENSCRAPER_TITLE_MEDIA_ARRAY" | jq -r '.')
    else
        media_type_array=$(echo "$SCREENSCRAPER_BOXART_MEDIA_ARRAY" | jq -r '.')
    fi
    # If not a JSON array, wrap as array
    if ! echo "$media_type_array" | grep -q '^\['; then
        media_type_array="[\"$media_type_array\"]"
    fi

    if [ "$REFRESH_CACHE" = "true" ] || [ ! -f "$artwork_file" ] || [ ! -s "$artwork_file" ]; then
        ls -A "$SDCARD_PATH/Roms/$ROM_FOLDER" >"$rom_file"

        download_count=0
        index=0
        total_count="$(wc -l <"$rom_file")"
        rom_count="$total_count"

        show_message "Searching for artwork for $rom_count ROMs" forever

        # Create output file
        > "$artwork_file"

        while read -r rom_name; do
            if [ -z "$rom_name" ]; then
                continue
            fi

            # ROM name cleaning (mirroring scrap_screenscraper.sh)
            romNameTrimmed="${rom_name/".nkit"/}"
            romNameTrimmed="${romNameTrimmed//"!"/}"
            romNameTrimmed="${romNameTrimmed//"&"/}"
            romNameTrimmed="${romNameTrimmed/"Disc "/}"
            romNameTrimmed="${romNameTrimmed/"Rev "/}"
            romNameTrimmed="$(echo "$romNameTrimmed" | sed -e 's/ ([^()]*)//g' -e 's/ [[A-z0-9!+]*]//g' -e 's/([^()]*)//g' -e 's/[[A-z0-9!+]*]//g')"
            romNameTrimmed="${romNameTrimmed//" - "/"%20"}"
            romNameTrimmed="${romNameTrimmed/"-"/"%20"}"
            romNameTrimmed="${romNameTrimmed//" "/"%20"}"

            # Remove file extension if present (for better search results)
            romNameTrimmedNoExt="${romNameTrimmed%.*}"

            # Check if already cached
            if [ -f "$SDCARD_PATH/Artwork/$ROM_FOLDER/$ART_TYPE/$rom_name.png" ] && [ "$REFRESH_CACHE" = "false" ]; then
                echo -e "$rom_name\t$SDCARD_PATH/Artwork/$ROM_FOLDER/$ART_TYPE/$rom_name.png" >> "$artwork_file"
                download_count=$((download_count + 1))
                continue
            fi

            # Get ROM size
            rom_path="$SDCARD_PATH/Roms/$ROM_FOLDER/$rom_name"
            if [ ! -f "$rom_path" ]; then
                continue
            fi
            rom_size=$(stat -c%s "$rom_path")

            # Only call jeuInfos once per ROM, then search for artwork types in the response
            found_media="false"

            # Brief progress message for this ROM
            show_message "Processing $rom_name" forever

            # Prepare cache file path using ROM base name (no extension)
            rom_base="${rom_name%.*}"
            jeuinfos_cache_file="$SDCARD_PATH/Artwork/.cache/jeuInfos/${rom_base}.json"

            # Load cached jeuInfos if available and not forcing refresh
            if [ "$REFRESH_CACHE" != "true" ] && [ -f "$jeuinfos_cache_file" ] && [ -s "$jeuinfos_cache_file" ]; then
                jeuinfos_response=$(cat "$jeuinfos_cache_file")
                show_message "Using cached info for $rom_name" forever
            else
                show_message "Fetching info from ScreenScraper for $rom_name" forever
                jeuinfos_params="romnom=${romNameTrimmedNoExt}.zip&romtype=rom&romtaille=${rom_size}&systemeid=${system_id}"
                jeuinfos_url=$(build_screenscraper_url "jeuInfos.php" "$jeuinfos_params")
                jeuinfos_response=$(screenscraper_curl "$jeuinfos_url")
                if [ $? -eq 0 ] && [ -n "$jeuinfos_response" ]; then
                    # Validate JSON before saving
                    if echo "$jeuinfos_response" | jq -e . >/dev/null 2>&1; then
                        tmpfile=$(mktemp)
                        echo "$jeuinfos_response" > "$tmpfile"
                        mv "$tmpfile" "$jeuinfos_cache_file"
                        show_message "Saved jeuInfos cache for $rom_name" forever
                    else
                        show_message "Invalid JSON from jeuInfos for $rom_name" 2
                    fi
                fi
            fi

            # If we have a valid response, search medias for the desired types
            if [ -n "$jeuinfos_response" ]; then
                if ! echo "$jeuinfos_response" | jq -e . >/dev/null 2>&1; then
                    show_message "Malformed jeuInfos JSON for $rom_name" 2
                else
                    for media_type in $(echo "$media_type_array" | jq -r '.[]'); do
                        # Collect all candidate URLs for this media type (one per line)
                        urls=$(echo "$jeuinfos_response" | jq -r ".response.jeu.medias[] | select(.type == \"$media_type\") | .url" 2>/dev/null)
                        if [ -n "$urls" ] && [ "$urls" != "null" ]; then
                            # Normalize line endings and remove CR characters
                            cleaned_urls=$(printf '%s\n' "$urls" | tr -d '\r')
                            # Try each URL separately (preserve here-doc to avoid subshell)
                            while IFS= read -r media_url; do
                                # Trim leading/trailing whitespace
                                media_url="$(echo "$media_url" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
                                if [ -z "$media_url" ] || [ "$media_url" = "null" ]; then
                                    continue
                                fi
                                # Basic URL validation
                                if ! echo "$media_url" | grep -qE '^https?://'; then
                                    show_message "Skipping invalid URL for $rom_name" forever
                                    continue
                                fi
                                show_message "Trying $media_type for $rom_name" forever
                                curl -fksSL -X GET -H "Content-Type: image/png" -H "User-Agent: MinUI-Artwork-Scraper/1.0" \
                                    -o "$SDCARD_PATH/Artwork/$ROM_FOLDER/$ART_TYPE/$rom_name.png" \
                                    "$media_url"
                                if [ $? -eq 0 ]; then
                                    show_message "Downloaded $rom_name ($media_type)" forever
                                    echo -e "$rom_name\t$SDCARD_PATH/Artwork/$ROM_FOLDER/$ART_TYPE/$rom_name.png" >> "$artwork_file"
                                    download_count=$((download_count + 1))
                                    found_media="true"
                                    # Successful download, exit both loops
                                    break 2
                                else
                                    show_message "Failed to download $rom_name image (type: $media_type) from $media_url" 2
                                fi
                            done <<EOF
$cleaned_urls
EOF
                        fi
                    done
                fi
            fi

            if [ "$found_media" != "true" ]; then
                show_message "No media found for $rom_name" 2
            fi

            iteration=$((download_count % 10))
            if [ "$iteration" -eq 0 ]; then
                index=$((index + 1))
                if [ $((index % 10)) -eq 0 ]; then
                    show_message "Processed $index/$total_count ROMs" forever
                fi
            fi
        done <"$rom_file"

        sync
    fi

    # Process downloaded images
    download_count=0
    total_count="$(wc -l <"$artwork_file")"
    rom_count="$(wc -l <"$rom_file")"

    show_message "Copying $download_count images to '$ROM_FOLDER' .$image_folder folder" forever
    while read -r line; do
        if [ -z "$line" ]; then
            continue
        fi

        rom_name="$(echo "$line" | cut -f1)"
        image_path="$(echo "$line" | cut -f2)"

        if [ -z "$rom_name" ] || [ -z "$image_path" ]; then
            continue
        fi

        if [ ! -f "$image_path" ]; then
            continue
        fi

        is_nextui=false
        image_folder="res"
        base_directory="$SDCARD_PATH/Roms/$ROM_FOLDER"
        if [ "$IS_NEXT" = "true" ] || [ "$IS_NEXT" = "yes" ]; then
            is_nextui=true
            image_folder="media"
        elif [ -f "$SHARED_USERDATA_PATH/minuisettings.txt" ]; then
            is_nextui=true
            image_folder="media"
        fi

        mkdir -p "$base_directory/.$image_folder/"
        filename="${rom_name%.*}"

        if [ "$is_nextui" = "true" ]; then
            cp -f "$image_path" "$base_directory/.$image_folder/$filename.png"
        else
            gm convert "$image_path" -resize "$MINUI_IMAGE_WIDTH" "$base_directory/.$image_folder/$rom_name.png"
        fi

        download_count=$((download_count + 1))
    done <"$artwork_file"

    sync

    show_message "Copied $download_count images for $rom_count roms" 4
}

get_emu_name() {
    EMU_FOLDER="$1"

    echo "$EMU_FOLDER" | sed 's/.*(\([^)]*\)).*/\1/'
}

# ScreenScraper system mapping
# Get ScreenScraper system ID from system_mapping.conf
# Get ScreenScraper system ID from systems_mapping.json
getSystemID() {
    local system_name="$1"
    local mapping_file="$PAK_DIR/systems_mapping.json"
    if [ ! -f "$mapping_file" ]; then
        show_message "systems_mapping.json not found" 4
        return 1
    fi
    # Use jq to search for system_name in any of the names arrays (case-insensitive)
    local system_id
    system_id=$(jq -r --arg name "$system_name" '
        .[] | select(.names[] | ascii_downcase == ($name | ascii_downcase)) | .id
    ' "$mapping_file" | head -1)
    if [ -n "$system_id" ] && [ "$system_id" != "null" ]; then
        echo "$system_id"
        return 0
    else
        show_message "No mapping found for system: $system_name" 4
        return 1
    fi
}

# Returns the artwork media type array (as a JSON array string) for the given art_type
get_artwork_media_type_array() {
    local art_type="$1"
    case "$art_type" in
        "snap")
            echo "$SCREENSCRAPER_SNAP_MEDIA_ARRAY"
            ;;
        "title")
            echo "$SCREENSCRAPER_TITLE_MEDIA_ARRAY"
            ;;
        "boxart")
            echo "$SCREENSCRAPER_BOXART_MEDIA_ARRAY"
            ;;
        *)
            echo '["screenshot"]'
            ;;
    esac
}

show_message() {
    message="$1"
    seconds="$2"

    if [ -z "$seconds" ]; then
        seconds="forever"
    fi

    killall minui-presenter >/dev/null 2>&1 || true
    echo "$message" 1>&2
    if [ "$seconds" = "forever" ]; then
        minui-presenter --message "$message" --timeout -1 &
    else
        minui-presenter --message "$message" --timeout "$seconds"
    fi
}

confirm_action() {
    message="$1"

    rm -f /tmp/confirm.list /tmp/confirm-output
    echo "Yes" >/tmp/confirm.list
    echo "No" >>/tmp/confirm.list

    killall minui-presenter >/dev/null 2>&1 || true
    minui-list --disable-auto-sleep --item-key "choices" --file "/tmp/confirm.list" --format text --cancel-text "CANCEL" --title "$message" --write-location /tmp/confirm-output --write-value state

    if [ $? -ne 0 ]; then
        return 1
    fi

    output="$(cat /tmp/confirm-output)"
    selected_index="$(echo "$output" | jq -r '.selected')"
    selection="$(echo "$output" | jq -r ".choices[$selected_index].name")"

    if [ "$selection" = "Yes" ]; then
        return 0
    else
        return 1
    fi
}

delete_all_images() {
    ROM_FOLDER="$1"

    confirm_action "Delete all artwork for $ROM_FOLDER?"
    if [ $? -ne 0 ]; then
        show_message "Deletion cancelled" 2
        return 1
    fi

    show_message "Deleting all images..." forever

    # Delete from cache
    rm -rf "$SDCARD_PATH/Artwork/$ROM_FOLDER"

    # Delete from rom folders (.res and .media)
    base_directory="$SDCARD_PATH/Roms/$ROM_FOLDER"
    rm -rf "$base_directory/.res"
    rm -rf "$base_directory/.media"

    # Delete cache files
    rm -f "$SDCARD_PATH/Artwork/.cache/matches/$ROM_FOLDER.in.txt"
    rm -f "$SDCARD_PATH/Artwork/.cache/matches/$ROM_FOLDER."*.out.txt

    sync
    show_message "All images deleted" 3
    return 0
}

select_images_to_delete() {
    ROM_FOLDER="$1"
    base_directory="$SDCARD_PATH/Roms/$ROM_FOLDER"

    # Determine which folder to check
    image_folder=".res"
    if [ -d "$base_directory/.media" ]; then
        image_folder=".media"
    fi

    if [ ! -d "$base_directory/$image_folder" ]; then
        show_message "No images found" 2
        return 1
    fi

    # Create list of images
    rm -f /tmp/images.list /tmp/images-output
    ls -1 "$base_directory/$image_folder"/*.png 2>/dev/null | while read -r img; do
        basename "$img" >>/tmp/images.list
    done

    if [ ! -s /tmp/images.list ]; then
        show_message "No images found" 2
        return 1
    fi

    killall minui-presenter >/dev/null 2>&1 || true
    minui-list --disable-auto-sleep --item-key "images" --file "/tmp/images.list" --format text --cancel-text "BACK" --title "Select image to delete" --write-location /tmp/images-output --write-value state

    if [ $? -ne 0 ]; then
        return 1
    fi

    output="$(cat /tmp/images-output)"
    selected_index="$(echo "$output" | jq -r '.selected')"
    selection="$(echo "$output" | jq -r ".images[$selected_index].name")"

    if [ -n "$selection" ]; then
        delete_single_image "$ROM_FOLDER" "$selection"
    fi
}

delete_single_image() {
    ROM_FOLDER="$1"
    IMAGE_NAME="$2"

    confirm_action "Delete $IMAGE_NAME?"
    if [ $? -ne 0 ]; then
        show_message "Deletion cancelled" 2
        return 1
    fi

    show_message "Deleting image..." forever

    # Delete from cache (all art types)
    rm -f "$SDCARD_PATH/Artwork/$ROM_FOLDER/snap/$IMAGE_NAME"
    rm -f "$SDCARD_PATH/Artwork/$ROM_FOLDER/title/$IMAGE_NAME"
    rm -f "$SDCARD_PATH/Artwork/$ROM_FOLDER/boxart/$IMAGE_NAME"

    # Delete from rom folders
    base_directory="$SDCARD_PATH/Roms/$ROM_FOLDER"
    rm -f "$base_directory/.res/$IMAGE_NAME"
    rm -f "$base_directory/.media/$IMAGE_NAME"

    sync
    show_message "Image deleted" 2
    return 0
}

clear_url_cache() {
    show_message "Clearing URL cache..." forever
    rm -rf "$SDCARD_PATH/Artwork/.cache/matches"
    rm -f "$SYSTEM_CACHE_FILE"
    sync
    show_message "URL cache cleared" 2
}

clear_image_cache() {
    show_message "Clearing image cache..." forever
    # Remove all cached images but keep the directory structure
    find "$SDCARD_PATH/Artwork" -type f -name "*.png" -exec rm {} \; || true
    sync
    show_message "Image cache cleared" 2
}

clear_all_cache() {
    show_message "Clearing all cache..." forever
    rm -rf "$SDCARD_PATH/Artwork/.cache"
    # Remove all cached images but keep the directory structure
    find "$SDCARD_PATH/Artwork" -type f -exec rm {} \; || true
    sync
    show_message "All cache cleared" 2
}

cache_menu() {
    # Create cache menu options
    cat >/tmp/cache_menu.list <<EOF
Clear URL cache only
Clear image cache only
Clear all cache
EOF

    killall minui-presenter >/dev/null 2>&1 || true
    minui-list --disable-auto-sleep --item-key "cache_options" --file "/tmp/cache_menu.list" --format text --cancel-text "BACK" --title "Cache Management" --write-location /tmp/cache-output --write-value state

    exit_code=$?
    if [ "$exit_code" -ne 0 ]; then
        rm -f /tmp/cache_menu.list /tmp/cache-output
        return 1
    fi

    output="$(cat /tmp/cache-output)"
    selected_index="$(echo "$output" | jq -r '.selected')"
    selection="$(echo "$output" | jq -r ".cache_options[$selected_index].name")"

    rm -f /tmp/cache_menu.list /tmp/cache-output

    case "$selection" in
    "Clear URL cache only")
        clear_url_cache
        ;;
    "Clear image cache only")
        clear_image_cache
        ;;
    "Clear all cache")
        clear_all_cache
        ;;
    esac
    return 0
}

provider_selection_menu() {
    rm -f /tmp/provider.list /tmp/provider-output
    echo "Bittersweet (Default)" >/tmp/provider.list
    echo "ScreenScraper" >>/tmp/provider.list

    current_provider="Bittersweet"
    [ "$ARTWORK_PROVIDER" = "screenscraper" ] && current_provider="ScreenScraper"

    killall minui-presenter >/dev/null 2>&1 || true
    minui-list --disable-auto-sleep --item-key "providers" --file "/tmp/provider.list" --format text --cancel-text "BACK" --title "Provider: $current_provider" --write-location /tmp/provider-output --write-value state

    if [ $? -ne 0 ]; then
        return 1
    fi

    output="$(cat /tmp/provider-output)"
    selected_index="$(echo "$output" | jq -r '.selected')"
    selection="$(echo "$output" | jq -r ".providers[$selected_index].name")"

    case "$selection" in
    "Bittersweet (Default)")
        save_settings "bittersweet"
        show_message "Provider set to Bittersweet" 2
        ;;
    "ScreenScraper")
        save_settings "screenscraper"
        show_message "Provider set to ScreenScraper" 2
        ;;
    esac
    return 0
}

settings_menu() {
    rm -f /tmp/settings_menu.list /tmp/settings-output
    echo "Change Scraper Provider" >/tmp/settings_menu.list

    killall minui-presenter >/dev/null 2>&1 || true
    minui-list --disable-auto-sleep --item-key "settings_options" --file "/tmp/settings_menu.list" --format text --cancel-text "BACK" --title "Settings" --write-location /tmp/settings-output --write-value state

    if [ $? -ne 0 ]; then
        return 1
    fi

    output="$(cat /tmp/settings-output)"
    selected_index="$(echo "$output" | jq -r '.selected')"
    selection="$(echo "$output" | jq -r ".settings_options[$selected_index].name")"

    case "$selection" in
    "Change Scraper Provider")
        provider_selection_menu
        ;;
    esac
    return 0
}

cleanup() {
    rm -f /tmp/stay_awake
    rm -f /tmp/emus
    rm -f /tmp/emus.list
    rm -f /tmp/minui-output
    rm -f /tmp/action.list
    rm -f /tmp/action-output
    rm -f /tmp/delete.list
    rm -f /tmp/delete-output
    rm -f /tmp/confirm.list
    rm -f /tmp/confirm-output
    rm -f /tmp/images.list
    rm -f /tmp/images-output
    killall minui-presenter >/dev/null 2>&1 || true
}

main() {
    echo "1" >/tmp/stay_awake
    trap "cleanup" EXIT INT TERM HUP QUIT

    if [ "$PLATFORM" = "tg3040" ] && [ -z "$DEVICE" ]; then
        export DEVICE="brick"
        export PLATFORM="tg5040"
    fi

    allowed_platforms="my355 tg5040"
    if ! echo "$allowed_platforms" | grep -q "$PLATFORM"; then
        show_message "$PLATFORM is not a supported platform" 2
        return 1
    fi

    if ! command -v minui-list >/dev/null 2>&1; then
        show_message "minui-list not found" 2
        return 1
    fi

    if ! command -v minui-presenter >/dev/null 2>&1; then
        show_message "minui-presenter not found" 2
        return 1
    fi

    chmod +x "$PAK_DIR/bin/$architecture/jq"
    chmod +x "$PAK_DIR/bin/$PLATFORM/minui-list"
    chmod +x "$PAK_DIR/bin/$PLATFORM/minui-presenter"

    while true; do
        main_screen
        exit_code=$?
        # exit codes: 2 = back button, 3 = menu button
        if [ "$exit_code" -ne 0 ]; then
            break
        fi

        output="$(cat /tmp/minui-output)"
        selected_index="$(echo "$output" | jq -r '.selected')"
        selection="$(echo "$output" | jq -r ".folders[$selected_index].name")"

        if [ -z "$selection" ]; then
            show_message "No selection made" forever
            continue
        fi

        # Handle Settings selection
        if [ "$selection" = "Settings" ]; then
            settings_menu
            continue
        fi

        # Handle Cache Management selection
        if [ "$selection" = "Cache Management" ]; then
            cache_menu
            # Refresh the emus list to ensure it's up to date
            rm -f /tmp/emus.list
            continue
        fi

        # Show action menu
        action=$(action_menu "$selection")
        if [ $? -ne 0 ]; then
            continue
        fi

        if [ "$action" = "Download Boxart as Artwork" ]; then
            show_message "Fetching boxart images for $selection" forever
            fetch_artwork "$selection" "boxart"
        elif [ "$action" = "Download Title as Artwork" ]; then
            show_message "Fetching title images for $selection" forever
            fetch_artwork "$selection" "title"
        elif [ "$action" = "Download Screenshot as Artwork" ]; then
            show_message "Fetching screenshot images for $selection" forever
            fetch_artwork "$selection" "snap"
        elif [ "$action" = "Delete Artwork" ]; then
            delete_option=$(delete_menu "$selection")
            if [ $? -eq 0 ]; then
                if [ "$delete_option" = "Delete All Images" ]; then
                    delete_all_images "$selection"
                elif [ "$delete_option" = "Delete Individual Images" ]; then
                    select_images_to_delete "$selection"
                fi
            fi
        fi
    done
}

main "$@"
