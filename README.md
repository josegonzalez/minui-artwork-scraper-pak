# minui-artwork-scraper.pak

A MinUI app that scrapes artwork for your MinUI or NextUI device.

## Requirements

This pak is designed and tested on the following MinUI Platforms and devices:

- `tg5040`: Trimui Brick (formerly `tg3040`), Trimui Smart Pro
- `rg35xxplus`: RG-35XX Plus, RG-34XX, RG-35XX H, RG-35XX SP

Use the correct platform for your device.

## Installation

1. Mount your MinUI SD card.
2. Download the latest release from Github. It will be named `Artwork.Scraper.pak.zip`.
3. Copy the zip file to `/Tools/$PLATFORM/Artwork Scraper.pak.zip`. Please ensure the new zip file name is `Artwork Scraper.pak.zip`, without a dot (`.`) between the words `Artwork` and `Scraper`.
4. Extract the zip in place, then delete the zip file.
5. Confirm that there is a `/Tools/$PLATFORM/Artwork Scraper.pak/launch.sh` file on your SD card.
6. Unmount your SD Card and insert it into your MinUI device.

## Usage

> [!IMPORTANT]
> If the zip file was not extracted correctly, the pak may show up under `Tools > Artwork`. Rename the folder to `Artwork Scraper.pak` to fix this.

Browse to `Tools > Artwork Scraper` and press `A` to enter the Pak.

### Debug Logging

To enable debug logging, create a file named `debug` in the `$SDCARD_PATH/.userdata/$PLATFORM/Artwork Scraper` folder. Logs will be written to the `$SDCARD_PATH/.userdata/$PLATFORM/logs/` folder.
