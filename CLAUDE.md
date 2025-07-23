# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

MinUI Artwork Scraper is a shell script-based application packaged as a MinUI `.pak` for handheld gaming devices. It automatically downloads game artwork from the Libretro Thumbnails Server based on ROM names.

## Key Commands

### Development
```bash
# Download required binaries (jq, minui-list, minui-presenter)
make build

# Create a distributable zip package
make release

# Update version in pak.json
make bump-version RELEASE_VERSION=x.x.x

# Deploy to device via ADB for testing
make push

# Clean built binaries
make clean
```

### Testing
To test locally, you need:
1. A tg5040 platform device (Trimui Brick/Smart Pro) connected via ADB
2. Run `make push` to deploy
3. Launch from the Tools menu in MinUI

## Architecture

### Core Components
- **launch.sh**: Main application entry point that handles:
  - Environment setup (PATH, LD_LIBRARY_PATH for platform binaries)
  - UI presentation using `minui-list` for emulator selection
  - API calls to matching server (`https://matching-images-is.bittersweet.rip`)
  - Image downloading from Libretro Thumbnails Server
  - Image processing and placement in `.res` (MinUI) or `.media` (NextUI) folders

### External Dependencies
- **Matching Server API**: `https://matching-images-is.bittersweet.rip/match` - Returns artwork URLs for ROM names
- **Image Source**: Libretro Thumbnails Server - Hosts the actual artwork files
- **Platform Tools**: `minui-list`, `minui-presenter`, `gm` (GraphicsMagick) - UI and image processing

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