# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

MinUI Artwork Scraper is a shell script-based application packaged as a MinUI `.pak` for handheld gaming devices. It automatically downloads game artwork from ScreenScraper API based on ROM names.

## Key Commands

### Development

```bash
# Clean build artifacts
make clean

# Download required binaries (jq, minui-list, minui-presenter)
make build

# Create a distributable zip package
make release

# Update version in pak.json
make bump-version RELEASE_VERSION=x.x.x

# Push to device via ADB
make push PUSH_SDCARD_PATH=/mnt/SDCARD PUSH_PLATFORM=tg5040
```

### Testing

To test locally, you need:

1. A tg5040 platform device (Trimui Brick/Smart Pro) connected via ADB
2. Run `make push` to deploy
3. Launch from the Tools menu in MinUI

## Architecture

### Core Components

1. **launch.sh** - Main entry point that:
   - Environment setup (PATH, LD_LIBRARY_PATH for platform binaries)
   - Sets up environment variables and paths
   - Manages UI through `minui-list` and `minui-presenter`
   - Handles artwork fetching and caching
   - API calls to ScreenScraper API (`https://api.screenscraper.fr/api2/`)
   - System mapping using `systemesListe.php`
   - Game searching using `jeuRecherche.php`
   - Image downloading using `jeuInfos.php` and `mediaJeu.php`
   - Image processing and placement in `.res` (MinUI) or `.media` (NextUI) folders

2. **Remote Service Integration**
   - Uses ScreenScraper API (`https://api.screenscraper.fr/api2/`) for game search and artwork download
   - Service endpoints: `systemesListe.php`, `jeuRecherche.php`, `jeuInfos.php`, `mediaJeu.php`
   - Input: ROM filenames and system names
   - Output: Direct artwork downloads with intelligent caching

3. **Caching Strategy**
   - Match cache: `$SDCARD_PATH/Artwork/.cache/matches/`
   - Downloaded images: `$SDCARD_PATH/Artwork/{ROM_FOLDER}/{ART_TYPE}/`
   - User configuration: `$USERDATA_PATH/Artwork Scraper/`

4. **Platform Detection**
   - Supports `arm` and `arm64` architectures
   - Platform-specific binaries in `bin/{architecture}/` and `bin/{platform}/`
   - Currently supports `tg5040` platform (Trimui devices)

### External Dependencies

- **ScreenScraper API**: `https://api.screenscraper.fr/api2/` - Game database and artwork provider
- **Configuration**: `screenscraper.conf` - API credentials and settings
- **Platform Tools**: `minui-list`, `minui-presenter`, `gm` (GraphicsMagick) - UI and image processing

### Key Environment Variables

- `$SDCARD_PATH` - Root path of SD card
- `$USERDATA_PATH` - User data directory (`.userdata/$PLATFORM/`)
- `$LOGS_PATH` - Debug log location
- `$PLATFORM` - Current device platform (e.g., `tg5040`)

### Image Processing

- MinUI requires images to be resized to 300px width (uses `graphicsmagick`)
- NextUI handles scaling in software
- Supported art types: `snap` (default), `title`, `boxart`

### Dependencies

External binaries downloaded during build:

- `jq` (v1.7.1) - JSON processing
- `minui-list` (v0.11.4) - Terminal UI list component
- `minui-presenter` (v0.7.0) - Message display component
- `graphicsmagick` (`gm`) - Image resizing (expected on device)

### Directory Structure

- `bin/`: Platform-specific binaries (jq for ARM/ARM64)
- `bin/tg5040/`: Platform tools (minui-list, minui-presenter, gm)
- `lib/tg5040/`: Shared libraries (libjpeg, libpng, libz)

### Image Processing Flow

1. User selects emulator via `minui-list`
2. Script loads ScreenScraper configuration from `screenscraper.conf`
3. Finds system ID using `systemesListe.php` (with caching)
4. Reads ROMs from emulator directory
5. Searches for each game using `jeuRecherche.php`
6. Downloads artwork using `jeuInfos.php` with appropriate media type
7. Copies/scales images to appropriate folders:
   - MinUI: `.res/` folders with 300px width scaling
   - NextUI: `.media/` folders without scaling

### Configuration

- **ScreenScraper API**: `screenscraper.conf` in package root (required)
  - `devid`: Developer ID (required)
  - `devpassword`: Developer password (required)
  - `softname`: Application name (optional, default: "MinUI Artwork Scraper")
  - `ssid`: ScreenScraper username (optional)
  - `sspassword`: ScreenScraper password (optional)
  - `output_format`: API response format (json/xml, default: json)
  - `max_retries`: Maximum retry attempts (default: 3)
  - `retry_delay`: Initial retry delay in seconds (default: 2)
  - `artwork_types`: Custom artwork type mappings

- Art type selection stored in `.userdata/$PLATFORM/.minui_artwork_scraper/.arttype`
- Options: snap (default), title, boxart
- Debug logs written to `.userdata/$PLATFORM/logs/minui_artwork_scraper.log`

## Development Notes

- The application runs in MinUI's environment with specific PATH requirements
- All user interaction happens through MinUI's presenter tools
- Error handling includes user-friendly messages via `minui-presenter`
- The script handles both MinUI and NextUI folder structures
- Platform detection is hardcoded to `tg5040` - extending to other platforms requires binary additions

## Release Process

1. Run `make release` to create distribution package
2. Creates `dist/Artwork Scraper.pak.zip` containing all necessary files
3. Version is automatically bumped if `RELEASE_VERSION` is provided
4. GitHub Actions handles attestation and artifact upload
## Recent Changes - ScreenScraper API improvements

This project received targeted updates to reduce API calls, improve robustness, and provide clearer runtime feedback when using the ScreenScraper API. Key changes (implemented in [`launch.sh`](launch.sh:1)):

- Single jeuInfos per ROM and persistent cache
  - The script now makes exactly one call to jeuInfos.php per ROM and persists the full JSON response to:
    - $SDCARD_PATH/Artwork/.cache/jeuInfos/{ROM_BASE}.json
  - Cached responses are reused on subsequent runs unless REFRESH_CACHE=true.

- Parse medias from cached jeuInfos JSON
  - All artwork type lookups (snap, title, boxart) are done by scanning the saved jeuInfos JSON and selecting medias by .type rather than making separate media API calls.
  - For each artwork type the code iterates candidate entries in the JSON and attempts downloads in order of the configured fallback list.

- Multiple URL handling and sanitization
  - jq results that return multiple URLs are handled as newline-separated candidates; each candidate is tried independently.
  - Each URL is sanitized (trim CR/LF and whitespace) and validated (basic https?:// pattern) before curl is invoked to avoid Illegal characters errors.

- Atomic save and JSON validation
  - Responses are validated with jq before saving.
  - Cache files are written atomically via a temporary file and mv to avoid corrupt cache states.

- Improved progress and persistent on-screen messages
  - The UI now shows clear progress messages at key points:
    - Per-ROM: processing, using cached info, or fetching info
    - Per-media attempt: trying a specific media type and download success/failure
    - Periodic processed summary (eg processed N/M ROMs)
  - Messages are displayed until the next message (using the presenter's forever mode) so the user sees current status without rapid flicker.

- Error handling and logging
  - Malformed JSON, failed downloads, and network/API errors are surfaced via existing show_message flow and written to the log file for debugging.
  - Existing retry/backoff behavior for API calls was preserved.

- Implementation notes
  - Changes are concentrated in the fetch flow inside [`launch.sh`](launch.sh:1) (fetch_artwork and related helpers).
  - New cache directory creation: $SDCARD_PATH/Artwork/.cache/jeuInfos
  - The previous behavior that avoids downloading existing images unless REFRESH_CACHE=true was preserved.

- Testing and next steps
  - Manual integration tests are recommended:
    - Run the scraper on a small ROM folder, confirm cache files appear under $SDCARD_PATH/Artwork/.cache/jeuInfos
    - Re-run to confirm cached responses are used and fewer API calls are made
    - Verify image files land under $SDCARD_PATH/Artwork/{ROM_FOLDER}/{ART_TYPE}/ and are copied/resized into .res or .media correctly
  - Additional tasks: update API docs, run shellcheck, and create a release commit / PR.

For implementation details, review the updated fetch logic in [`launch.sh`](launch.sh:1) and the artwork cache location listed above.
