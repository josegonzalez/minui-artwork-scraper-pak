package main

import (
	"bufio"
	"flag"
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"strings"

	fuzzy "github.com/paul-mannino/go-fuzzywuzzy"
)

const (
	libretroThumbnailsURL = "https://thumbnails.libretro.com"
)

var consoleNames = map[string]string{
	"FC":   "Nintendo - Nintendo Entertainment System",
	"SFC":  "Nintendo - Super Nintendo Entertainment System",
	"MD":   "Sega - Mega Drive - Genesis",
	"GB":   "Nintendo - Game Boy",
	"GBC":  "Nintendo - Game Boy Color",
	"GBA":  "Nintendo - Game Boy Advance",
	"PS":   "Sony - PlayStation",
	"PCE":  "NEC - PC Engine - TurboGrafx 16",
	"NGP":  "SNK - Neo Geo Pocket",
	"GG":   "Sega - Game Gear",
	"SMS":  "Sega - Master System - Mark III",
	"WS":   "Bandai - WonderSwan",
	"LNX":  "Atari - Lynx",
	"POKE": "Nintendo - Pokemon Mini",
}

func cleanROMName(filename string) string {
	base := filepath.Base(filename)
	ext := filepath.Ext(base)
	name := strings.TrimSuffix(base, ext)
	
	name = strings.ReplaceAll(name, "&", "_")
	name = strings.ReplaceAll(name, "'", "_")
	name = strings.ReplaceAll(name, "!", "_")
	name = strings.ReplaceAll(name, ":", "_")
	name = strings.ReplaceAll(name, "/", "_")
	name = strings.ReplaceAll(name, "\\", "_")
	
	return name
}

func generateThumbnailURL(console, artType, gameName string) string {
	consolePath := consoleNames[console]
	if consolePath == "" {
		consolePath = console
	}
	
	encodedConsole := url.QueryEscape(consolePath)
	encodedArtType := url.QueryEscape(artType)
	encodedGameName := url.QueryEscape(gameName)
	
	return fmt.Sprintf("%s/%s/%s/%s.png", libretroThumbnailsURL, encodedConsole, encodedArtType, encodedGameName)
}

func findBestMatch(romName string, possibleMatches []string) (string, int) {
	bestMatch := ""
	bestScore := 0
	
	cleanedROM := cleanROMName(romName)
	
	for _, candidate := range possibleMatches {
		score := fuzzy.TokenSortRatio(cleanedROM, candidate)
		if score > bestScore {
			bestScore = score
			bestMatch = candidate
		}
	}
	
	if bestScore < 60 {
		score := fuzzy.PartialRatio(cleanedROM, cleanedROM)
		if score > bestScore {
			bestMatch = cleanedROM
			bestScore = score
		}
	}
	
	return bestMatch, bestScore
}

func main() {
	var console string
	var artType string
	
	flag.StringVar(&console, "console", "", "Console/emulator name (e.g., FC, SFC, MD)")
	flag.StringVar(&artType, "type", "Named_Boxarts", "Art type (Named_Boxarts, Named_Titles, Named_Snaps)")
	flag.Parse()
	
	if console == "" {
		fmt.Fprintf(os.Stderr, "Error: -console flag is required\n")
		flag.Usage()
		os.Exit(1)
	}
	
	scanner := bufio.NewScanner(os.Stdin)
	for scanner.Scan() {
		romFile := scanner.Text()
		if romFile == "" {
			continue
		}
		
		cleanedName := cleanROMName(romFile)
		thumbnailURL := generateThumbnailURL(console, artType, cleanedName)
		
		fmt.Printf("%s\t%s\n", romFile, thumbnailURL)
	}
	
	if err := scanner.Err(); err != nil {
		fmt.Fprintf(os.Stderr, "Error reading input: %v\n", err)
		os.Exit(1)
	}
}