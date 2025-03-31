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

Browse to `Tools > Artwork Scraper` and press `A` to enter the Pak. A list of emulator folders with roms inside will be populated. Selecting a folder will hit a [remote server](https://matching-images-is.bittersweet.rip) running the [`libretro-image-matching-server`](https://github.com/josegonzalez/libretro-image-matching-server) codebase for matching rom names to `Named_Snap` images, which will be cached to disk for later usage. Once the cache is populated, all the matched will be downloaded and moved into the correct folder for either MinUI or NextUI.

Images are downloaded from the [Libretro Thumbnails Server](https://thumbnails.libretro.com/) and cached locally to an `Artwork` directory. Only snapshots are downloaded at this time.

Matching is currently performed on a remote server to increase the likelihood of an image download regardless of your game names, but will occasionally be incorrect. In such cases, you may delete the image manually in the correct `.media` (NextUI) or `.res` (MinUI) folder.

Images are not currently resized from the original resolution, and thus may look either too small or too large on MinUI devices as MinUI does not dynamically resize images (NextUI will properly resize them).

> [!WARNING]
> Please note that it is currently not possible to exit out of the scraping process once it has started. You may need to power down your device to force-exit scraping.

### Debug Logging

Debug logs will be written to the `$SDCARD_PATH/.userdata/$PLATFORM/logs/` folder.
