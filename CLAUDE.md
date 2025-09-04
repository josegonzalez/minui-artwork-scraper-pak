# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

MinUI Artwork Scraper is a shell script-based application packaged as a MinUI `.pak` for handheld gaming devices. It automatically downloads game artwork from the Libretro Thumbnails Server based on ROM names.

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
   - API calls to matching server (`https://matching-images-is.bittersweet.rip`)
   - Image downloading from Libretro Thumbnails Server
   - Image processing and placement in `.res` (MinUI) or `.media` (NextUI) folders

2. **Remote Service Integration**
   - Uses `https://matching-images-is.bittersweet.rip` for fuzzy ROM name matching
   - Service endpoint: `POST /matches/{emu_name}/{art_type}`
   - Input: List of ROM filenames
   - Output: Tab-delimited file with ROM name to artwork URL mappings

3. **Caching Strategy**
   - Match cache: `$SDCARD_PATH/Artwork/.cache/matches/`
   - Downloaded images: `$SDCARD_PATH/Artwork/{ROM_FOLDER}/{ART_TYPE}/`
   - User configuration: `$USERDATA_PATH/Artwork Scraper/`

4. **Platform Detection**
   - Supports `arm` and `arm64` architectures
   - Platform-specific binaries in `bin/{architecture}/` and `bin/{platform}/`
   - Currently supports `tg5040` platform (Trimui devices)

### External Dependencies

- **Matching Server API**: `https://matching-images-is.bittersweet.rip/match` - Returns artwork URLs for ROM names
- **Image Source**: Libretro Thumbnails Server - Hosts the actual artwork files
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
2. Script reads ROMs from emulator directory
3. Calls matching API with ROM names
4. Downloads images to local cache (`.cache/minui_artwork_scraper/`)
5. Copies/scales images to appropriate folders:
   - MinUI: `.res/` folders with 300px width scaling
   - NextUI: `.media/` folders without scaling

### Configuration

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
