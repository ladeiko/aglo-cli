.PHONY: all build test unit-test cli-test xcode generate-linuxmain install clean

mkfile_dir  := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

all: install

clean:
	rm -rf "$(mkfile_dir)/.build"

build:
	swift build -c release

unit-test:
	swift test

cli-test:
	find ./cli-test -name "cmd.sh" -exec bash "{}" \;

test: unit-test

xcode:
	swift package generate-xcodeproj

generate-linuxmain:
	swift test --generate-linuxmain

install: build
	cp -f "$(mkfile_dir)/.build/release/aglo-cli" /usr/local/bin/
