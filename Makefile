PAK_NAME := $(shell jq -r .name pak.json)
PAK_TYPE := $(shell jq -r .type pak.json)
PAK_FOLDER := $(shell echo $(PAK_TYPE) | cut -c1)$(shell echo $(PAK_TYPE) | tr '[:upper:]' '[:lower:]' | cut -c2-)s

PUSH_SDCARD_PATH ?= /mnt/SDCARD
PUSH_PLATFORM ?= tg5040

ARCHITECTURES := arm arm64
PLATFORMS := h700 my355 tg5040 tg5050

JQ_VERSION := 1.7.1
MINUI_LIST_VERSION := 0.13.0
MINUI_PRESENTER_VERSION := 0.12.0
H700_MINUI_LIST_VERSION := 0.15.0
H700_MINUI_PRESENTER_VERSION := 0.13.0

clean:
	rm -f bin/*/jq || true
	rm -f bin/*/jq.LICENSE || true
	rm -f bin/*/minui-list || true
	rm -f bin/*/minui-presenter || true

build: $(foreach platform,$(PLATFORMS),bin/$(platform)/minui-list bin/$(platform)/minui-presenter) $(foreach arch,$(ARCHITECTURES),bin/$(arch)/jq)

bin/h700/minui-list:
	mkdir -p bin/h700
	curl -f -o bin/h700/minui-list -sSL https://github.com/josegonzalez/minui-list/releases/download/$(H700_MINUI_LIST_VERSION)/minui-list-h700-nextui
	chmod +x bin/h700/minui-list

bin/h700/minui-presenter:
	mkdir -p bin/h700
	curl -f -o bin/h700/minui-presenter -sSL https://github.com/josegonzalez/minui-presenter/releases/download/$(H700_MINUI_PRESENTER_VERSION)/minui-presenter-h700-nextui
	chmod +x bin/h700/minui-presenter

bin/arm/jq:
	mkdir -p bin/arm
	curl -f -o bin/arm/jq -sSL https://github.com/jqlang/jq/releases/download/jq-$(JQ_VERSION)/jq-linux-armhf
	curl -sSL -o bin/arm/jq.LICENSE "https://raw.githubusercontent.com/jqlang/jq/refs/heads/$(JQ_VERSION)/COPYING"

bin/arm64/jq:
	mkdir -p bin/arm64
	curl -f -o bin/arm64/jq -sSL https://github.com/jqlang/jq/releases/download/jq-$(JQ_VERSION)/jq-linux-arm64
	curl -sSL -o bin/arm64/jq.LICENSE "https://raw.githubusercontent.com/jqlang/jq/refs/heads/$(JQ_VERSION)/COPYING"

bin/%/minui-list:
	mkdir -p bin/$*
	curl -f -o bin/$*/minui-list -sSL https://github.com/josegonzalez/minui-list/releases/download/$(MINUI_LIST_VERSION)/minui-list-$*
	chmod +x bin/$*/minui-list

bin/%/minui-presenter:
	mkdir -p bin/$*
	curl -f -o bin/$*/minui-presenter -sSL https://github.com/josegonzalez/minui-presenter/releases/download/$(MINUI_PRESENTER_VERSION)/minui-presenter-$*
	chmod +x bin/$*/minui-presenter

release: build
	mkdir -p dist
	git archive --format=zip --output "dist/$(PAK_NAME).pak.zip" HEAD
	while IFS= read -r file; do zip -r "dist/$(PAK_NAME).pak.zip" "$$file"; done < .gitarchiveinclude
	$(MAKE) bump-version
	zip -r "dist/$(PAK_NAME).pak.zip" pak.json
	ls -lah dist

bump-version:
	jq '.version = "$(RELEASE_VERSION)"' pak.json > pak.json.tmp
	mv pak.json.tmp pak.json

push: release
	rm -rf "dist/$(PAK_NAME).pak"
	cd dist && unzip "$(PAK_NAME).pak.zip" -d "$(PAK_NAME).pak"
	adb push "dist/$(PAK_NAME).pak/." "$(PUSH_SDCARD_PATH)/$(PAK_FOLDER)/$(PUSH_PLATFORM)/$(PAK_NAME).pak"
