# agy-mcp

A tiny [MCP](https://modelcontextprotocol.io) server that exposes the
Antigravity CLI (`agy`) — a Gemini agent — as a single tool. A parent agent
(Claude Code, etc.) calls the tool with a task; this server runs
`agy --print <task>`, lets Gemini perform it, and returns Gemini's response.
In effect: a **spawned Gemini sub-agent callable from inside another agent**.

## Tool: `gemini_agent`

| Param | Type | Default | Notes |
|---|---|---|---|
| `task` | string (required) | — | The complete, self-contained task/prompt for Gemini. |
| `add_dirs` | string[] | — | Directories to add to the agent's workspace (absolute paths). |
| `working_dir` | string | server cwd | Directory the agent runs in. |
| `timeout_seconds` | number | 300 (max 1800) | Maps to `agy --print-timeout`. |
| `allow_tools` | bool | **false** | Let the agent take actions (edit files / run commands) by auto-approving its permission prompts (`--dangerously-skip-permissions`). |
| `sandbox` | bool | `allow_tools` | Run with terminal/sandbox restrictions (`--sandbox`). Defaults on when `allow_tools` is on. |

### Safety model

By default the spawned agent is **reason/answer only** — it runs `agy --print`
with no permission bypass, so it can analyze, draft, and answer but cannot take
unattended actions. To let it actually act on your files/system, the caller must
explicitly pass `allow_tools: true`, which:

- passes `--dangerously-skip-permissions` (Gemini's approval gates are off — this
  is unattended execution), and
- runs inside `--sandbox` by default (override with `sandbox: false`).

The tool result header always reports whether tool-use was enabled.

## Build

```sh
go build -o agy-mcp .          # local binary
# or
go install github.com/adubkov/agy-mcp@latest
```

Requires `agy` on `PATH` (or set `AGY_BIN=/path/to/agy`). The server falls back
to `~/.local/bin/agy`.

## Register with Claude Code

User scope (available in every project):

```sh
claude mcp add agy --scope user -- /Users/adubkov/Development/go/src/github.com/adubkov/agy-mcp/agy-mcp
```

Or project scope via `.mcp.json` in a repo root:

```json
{
  "mcpServers": {
    "agy": {
      "command": "/Users/adubkov/Development/go/src/github.com/adubkov/agy-mcp/agy-mcp",
      "env": { "AGY_BIN": "/Users/adubkov/.local/bin/agy" }
    }
  }
}
```

Restart Claude Code (MCP servers load at session start). The tool then appears as
`gemini_agent`.

## Install as a Claude Code plugin (recommended)

This repo is also a Claude Code **plugin** (`agy-gemini`): installing it wires the
MCP server *and* ships a skill (`skills/gemini-agent/SKILL.md`) that teaches Claude
when and how to delegate to `gemini_agent`.

```sh
make build         # produce the agy-mcp binary the plugin's .mcp.json references
make plugin-link   # symlink this repo into ~/.claude/plugins/agy-gemini
# then restart Claude Code
```

The plugin bundles:

- `.claude-plugin/plugin.json` — plugin manifest.
- `.mcp.json` — registers the `agy` MCP server (`${CLAUDE_PLUGIN_ROOT}/agy-mcp`).
- `skills/gemini-agent/SKILL.md` — guidance for Claude on delegating tasks
  (when to use it, the two modes, how to write a good `task`, and "always verify
  the output").

## Build (Makefile)

```sh
make build    # compile ./agy-mcp (referenced by .mcp.json)
make install  # go install into $GOBIN
make vet      # static checks
make smoke    # build + drive the stdio server through a reason-only round-trip
make help     # list targets
```

## Example calls

Reason-only (safe default):

```json
{ "task": "Review this Go error-handling pattern and suggest improvements: ..." }
```

Acting mode — let Gemini edit files (auto-approves its permission prompts; scope
it with `working_dir` and verify the diff afterward):

```json
{
  "task": "Rename the symbol Foo to Bar across this package and update callers. Make the edits and list the files you changed.",
  "working_dir": "/path/to/project",
  "add_dirs": ["/path/to/project"],
  "allow_tools": true
}
```

Reason-only (safe default):

```json
{ "task": "Review this Go error-handling pattern and suggest improvements: ..." }
```

Let it act, with workspace context:

```json
{
  "task": "Rename the symbol Foo to Bar across this package and update callers.",
  "working_dir": "/path/to/project",
  "add_dirs": ["/path/to/project"],
  "allow_tools": true
}
```
