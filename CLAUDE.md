# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a MinUI tool package (`.pak`) that scrapes artwork from the Libretro Thumbnails Server for retro gaming devices. It's written primarily in shell script and targets ARM-based gaming handhelds running MinUI/NextUI.

## Development Commands

### Build Commands
```bash
# Clean build artifacts
make clean

# Build all dependencies (downloads pre-built binaries)
make build

# Create release package
make release

# Version bump (requires RELEASE_VERSION environment variable)
make bump-version RELEASE_VERSION=x.y.z

# Push to device via ADB
make push PUSH_SDCARD_PATH=/mnt/SDCARD PUSH_PLATFORM=tg5040
```

### Testing
- No unit tests exist - testing is done via CI/CD pipeline
- CI runs on ARM-based Ubuntu runners and validates build artifacts
- Manual testing requires a physical MinUI device or ADB access

## Architecture

### Core Components

1. **launch.sh** - Main entry point that:
   - Sets up environment variables and paths
   - Manages UI through `minui-list` and `minui-presenter`
   - Handles artwork fetching and caching
   - Integrates with remote image matching service

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

### Key Environment Variables
- `$SDCARD_PATH` - Root path of SD card
- `$USERDATA_PATH` - User data directory (`.userdata/$PLATFORM/`)
- `$LOGS_PATH` - Debug log location
- `$PLATFORM` - Current device platform (e.g., `tg5040`)

### Image Processing
- MinUI requires images to be resized to 300px width (uses `graphicsmagick`)
- NextUI handles scaling in software
- Supported art types: `snap` (default), `title`, `boxart`

## Dependencies

External binaries downloaded during build:
- `jq` (v1.7.1) - JSON processing
- `minui-list` (v0.11.4) - Terminal UI list component
- `minui-presenter` (v0.7.0) - Message display component
- `graphicsmagick` (`gm`) - Image resizing (expected on device)

## Release Process

1. Run `make release` to create distribution package
2. Creates `dist/Artwork Scraper.pak.zip` containing all necessary files
3. Version is automatically bumped if `RELEASE_VERSION` is provided
4. GitHub Actions handles attestation and artifact upload