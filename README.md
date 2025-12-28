# minui-artwork-scraper.pak

A MinUI app that scrapes artwork from the [Libretro Thumbnails Server](https://thumbnails.libretro.com/) for your MinUI or NextUI device.

## Requirements

This pak is designed and tested on the following MinUI Platforms and devices:

- `my355`: Miyoo Flip
- `tg5040`: Trimui Brick (formerly `tg3040`), Trimui Smart Pro

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

Browse to `Tools > Artwork Scraper` and press `A` to enter the Pak. A list of emulator folders with roms inside will be populated, with a "Cache Management" option at the top. Selecting an emulator and choosing an option to download artwork will hit a [remote server](https://matching-images-is.bittersweet.rip) running the [`libretro-image-matching-server`](https://github.com/josegonzalez/libretro-image-matching-server) codebase for matching rom names to images, which will be cached to disk for later usage. Once the cache is populated, all the matched will be downloaded and moved into the correct folder for either MinUI or NextUI.

- Images are downloaded from the [Libretro Thumbnails Server](https://thumbnails.libretro.com/) and cached locally to an `Artwork` directory.
- By default, `snap` (image screenshots) are the art type downloaded, but `title` and `boxart` can also be used.
- Images are copied from the `Artwork` directory cache to the `.media` (NextUI) or `.res` (MinUI) folder.
- Matching is currently performed on a remote server to increase the likelihood of an image download regardless of your game names, but will occasionally be incorrect. In such cases, you may delete the image manually in the correct `.media` (NextUI) or `.res` (MinUI) folder.
- NextUI will scale images appropriately for the screen in software.
- MinUI does not perform image scaling, and image scaling is performed during the copy step using `graphicsmagick`.

> [!WARNING]
> Please note that it is currently not possible to exit out of the scraping process once it has started. You may need to power down your device to force-exit scraping.

### Cache Management

The "Cache Management" option appears at the top of the emulator list and allows you to manage the cached data:

- **Clear URL cache only**: Removes the cached mappings between ROM names and artwork URLs. This forces the scraper to re-query the remote server for matches.
- **Clear image cache only**: Removes all downloaded artwork images while preserving the URL mappings. This is useful if you want to re-download images without re-matching.
- **Clear all cache**: Removes both URL mappings and downloaded images, giving you a fresh start.

### Debug Logging

Debug logs will be written to the `$SDCARD_PATH/.userdata/$PLATFORM/logs/` folder.

### System Mapping Configuration

The artwork scraper now includes a local system mapping configuration file (`system_mapping.conf`) that provides fallback system IDs when the ScreenScraper API is unavailable. This ensures the scraper continues to work even with network connectivity issues.

#### File Format

The `system_mapping.conf` file uses a simple key-value format:

```ini
# ScreenScraper System ID Mappings
# Format: SYSTEM_NAME=SYSTEM_ID
# These mappings provide local fallback when API is unavailable

# Nintendo Systems
GBC=10
GB=11
GBA=12
N64=43
NES=6
SNES=7

# Sony Systems
PS=1
PSP=16

# Sega Systems
MD=18
SMS=17
GG=15
```

#### Adding New Systems

To add a new system mapping:

1. Find the system ID from the ScreenScraper API:
   - Visit https://api.screenscraper.fr/api2/systemesListe.php
   - Use your developer credentials to get the full system list
   - Find your system in the response and note its ID

2. Add the mapping to `system_mapping.conf`:
   ```ini
   YOUR_SYSTEM_NAME=SystemID
   ```

3. The system name should match the folder name pattern extracted by `get_emu_name()` (the text inside parentheses).

#### Fallback Mechanism

The system ID resolution follows this priority:

1. **Local Mapping**: Check `system_mapping.conf` first (fastest, no network required)
2. **Cache**: Check previously cached API responses
3. **API**: Query ScreenScraper API as last resort
4. **Error**: Show user-friendly message if all methods fail

This approach ensures reliability while maintaining performance for common systems.

#### Troubleshooting

If you encounter system ID resolution issues:

1. Check if your system is listed in `system_mapping.conf`
2. Verify the folder name format matches the expected pattern
3. Test connectivity to the ScreenScraper API
4. Check the debug logs for detailed error messages
