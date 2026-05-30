BINARY := agy-mcp
PKG    := github.com/adubkov/agy-mcp

.PHONY: build install vet test clean smoke plugin-link help

## build: compile the MCP server binary into the repo root (referenced by .mcp.json)
build:
	go build -o $(BINARY) .

## install: go install the binary into $GOBIN / $GOPATH/bin
install:
	go install .

## vet: static checks
vet:
	go vet ./...

## test: run tests
test:
	go test ./...

## smoke: build + drive the stdio server through initialize + a reason-only tools/call
smoke: build
	@printf '%s\n' \
	'{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"smoke","version":"0"}}}' \
	'{"jsonrpc":"2.0","method":"notifications/initialized"}' \
	'{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"gemini_agent","arguments":{"task":"Reply with exactly the word: PONG","timeout_seconds":60}}}' \
	| ./$(BINARY) | grep -q PONG && echo "smoke OK" || (echo "smoke FAILED"; exit 1)

## plugin-link: symlink this repo into the Claude Code plugins dir for local use
plugin-link: build
	mkdir -p $(HOME)/.claude/plugins
	ln -sfn $(CURDIR) $(HOME)/.claude/plugins/agy-gemini
	@echo "linked $(CURDIR) -> ~/.claude/plugins/agy-gemini (restart Claude Code to load)"

## clean: remove the built binary
clean:
	rm -f $(BINARY)

## help: list targets
help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## //'
