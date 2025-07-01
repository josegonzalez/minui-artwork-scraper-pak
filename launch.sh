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
export MINUI_IMAGE_WIDTH=300

get_art_type() {
    ART_TYPE_FILE="$USERDATA_PATH/$PAK_NAME/art-type"

    if [ ! -f "$ART_TYPE_FILE" ]; then
        rm -f /tmp/arttype.list /tmp/arttype-output

        echo "snap" > /tmp/arttype.list
        echo "title" >> /tmp/arttype.list
        echo "boxart" >> /tmp/arttype.list

        minui-list \
            --disable-auto-sleep \
            --item-key "types" \
            --file "/tmp/arttype.list" \
            --format text \
            --title "Artwork Type" \
            --cancel-text "Default (snap)" \
            --write-location /tmp/arttype-output \
            --write-value state

        if [ -f /tmp/arttype-output ]; then
            selected_index="$(jq -r '.selected' /tmp/arttype-output)"
            selected_type="$(jq -r ".types[$selected_index].name" /tmp/arttype-output)"
        fi

        if [ -z "$selected_type" ]; then
            selected_type="snap"
        fi

        echo "$selected_type" > "$ART_TYPE_FILE"
    fi

    cat "$ART_TYPE_FILE"
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
    echo "Reset Artwork Type" >> /tmp/emus.list
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

fetch_artwork() {
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

    download_count=0
    total_count="$(wc -l <"$artwork_file")"
    rom_count="$(wc -l <"$rom_file")"
    show_message "Ensuring artwork is cached" forever
    while read -r line; do
        [ -z "$line" ] && continue

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
        [ "$iteration" -eq 0 ] && show_message "Downloaded $download_count/$total_count" forever
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
        rom_name="$(echo "$line" | cut -f1)"
        filename="${rom_name%.*}"

        mkdir -p "$base_directory/.$image_folder/"
        if [ "$is_nextui" = "true" ]; then
            cp -f "$SDCARD_PATH/Artwork/$ROM_FOLDER/$ART_TYPE/$rom_name.png" "$base_directory/.$image_folder/$filename.png"
        else
            gm convert "$SDCARD_PATH/Artwork/$ROM_FOLDER/$ART_TYPE/$rom_name.png" -resize "$MINUI_IMAGE_WIDTH" "$base_directory/.$image_folder/$rom_name.png"
        fi
    done <"$artwork_file"

    sync
    show_message "Copied $download_count images for $rom_count roms" 4
}

get_emu_name() {
    EMU_FOLDER="$1"
    echo "$EMU_FOLDER" | sed 's/.*(\([^)]*\)).*/\1/'
}

show_message() {
    message="$1"
    seconds="$2"
    [ -z "$seconds" ] && seconds="forever"

    killall minui-presenter >/dev/null 2>&1 || true
    echo "$message" 1>&2
    if [ "$seconds" = "forever" ]; then
        minui-presenter --message "$message" --timeout -1 &
    else
        minui-presenter --message "$message" --timeout "$seconds"
    fi
}

reset_art_type() {
    ART_TYPE_FILE="$USERDATA_PATH/$PAK_NAME/art-type"
    if [ -f "$ART_TYPE_FILE" ]; then
        rm -f "$ART_TYPE_FILE"
        show_message "Artwork type reset. Restart to select again." 3
    else
        show_message "No artwork type set." 3
    fi
}

cleanup() {
    rm -f /tmp/stay_awake
    rm -f /tmp/emus
    rm -f /tmp/minui-output
    killall minui-presenter >/dev/null 2>&1 || true
}

main() {
    echo "1" >/tmp/stay_awake
    trap "cleanup" EXIT INT TERM HUP QUIT

    if [ "$PLATFORM" = "tg3040" ] && [ -z "$DEVICE" ]; then
        export DEVICE="brick"
        export PLATFORM="tg5040"
    fi

    allowed_platforms="tg5040"
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
        if [ "$exit_code" -ne 0 ]; then
            break
        fi

        output="$(cat /tmp/minui-output)"
        selected_index="$(echo "$output" | jq -r '.selected')"
        selection="$(echo "$output" | jq -r ".folders[$selected_index].name")"

        if [ "$selection" = "Reset Artwork Type" ]; then
            reset_art_type
            continue
        fi

        if [ -z "$selection" ]; then
            show_message "No selection made" forever
            continue
        fi

        art_type="$(get_art_type)"
        show_message "Fetching $art_type images for $selection" forever
        fetch_artwork "$selection" "$art_type"
    done
}

main "$@"
