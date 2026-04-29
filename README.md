# TokenHUD

TokenHUD is a local-first statusline and spend ledger for AI CLI sessions. The
Codex adapter is implemented today; Claude Code, Aider, Cursor, and local
llamacpp adapters are planned behind the same interface.

For Codex, TokenHUD reads `~/.codex/sessions/**/*.jsonl`, finds the latest
`token_count` event, and renders context usage, token usage, estimated API cost,
Codex credits, rate limits, model, git state, and session metadata.

The main command is `tokenhud`. `codexhud` remains as a compatibility alias for
the Codex adapter.

## Features

- Token counts from local AI CLI telemetry.
- Codex adapter for local `token_count` session JSONL.
- Estimated USD and Codex credit cost from a local model price table.
- Current context window usage with compact risk labels.
- Rate limit percentages and reset windows when Codex emits them.
- Git branch and dirty-file count for the active session cwd.
- `tmux`, compact, full, JSON, adapter table, model table, and style-gallery modes.
- `TOKENHUD_*` configuration, with `CODEXHUD_*` accepted for compatibility.

## Install

```bash
./install.sh
```

This links `bin/tokenhud` to `~/.local/bin/tokenhud`, keeps
`~/.local/bin/codexhud` as an alias, and installs the default price config to
`~/.tokenhud/prices.json` if that file does not already exist. If an existing
`~/.codexhud/prices.json` is found, the installer migrates it to the new
TokenHUD config directory.

Use `TOKENHUD_INSTALL_MODE=copy ./install.sh` if you prefer copying the binary.
`CODEXHUD_INSTALL_MODE` is still accepted.

## Usage

```bash
tokenhud tmux
tokenhud compact
tokenhud full
tokenhud json
tokenhud adapters
tokenhud models
tokenhud prices-check
tokenhud styles
tokenhud launch codex
tokenhud status
tokenhud init bash
tokenhud init zsh
```

`codexhud tmux` and the other existing `codexhud` commands continue to work.

Useful environment variables:

```bash
TOKENHUD_STYLE=balanced   # balanced|minimal|ledger|risk|executive|focus|ascii
TOKENHUD_ADAPTER=codex    # non-Codex adapters render as pending until implemented
TOKENHUD_MODEL=gpt-5.5    # override model detection for the active adapter
TOKENHUD_ASCII=1          # force ASCII progress bars
TOKENHUD_PROMPT=0         # temporarily disable shell prompt integration
TOKENHUD_DEBUG=1          # log prompt refresh errors to cache/refresh.log
TOKENHUD_HOME=~/.tokenhud
TOKENHUD_CACHE_DIR=~/.tokenhud/cache
TOKENHUD_PRICE_FILE=~/.tokenhud/prices.json
TOKENHUD_PRICES_CHECK_FETCH=1 # optional URL reachability probes
TOKENHUD_TAIL_LINES=500    # 0 scans the full JSONL directly
TOKENHUD_CACHE_TTL=2
TOKENHUD_STATUS_CACHE_TTL=30
TOKENHUD_SESSION_SCAN_TTL=60
TOKENHUD_SESSION_SCAN_LIMIT=0 # 0 scans all sessions when matching cwd
TOKENHUD_LAUNCH_TMUX=1        # launch opens tmux when outside tmux
TOKENHUD_LAUNCH_SESSION_PREFIX=tokenhud
TOKENHUD_TMUX_STATUS=1        # launch sets a session-local tmux statusline
TOKENHUD_TMUX_INTERVAL=5
TOKENHUD_TMUX_RIGHT_LENGTH=180
CODEX_HOME=~/.codex          # override Codex home
```

## Always-On Launch

For plain terminals, Codex owns the screen while its TUI is running, so a prompt
hook cannot draw above the input box. Use `tokenhud launch` to start the CLI in
a tmux session where TokenHUD can stay visible in the statusline:

```bash
tokenhud launch codex
```

The launcher sets a session-local tmux statusline for the AI CLI. It runs the
command directly when already inside tmux. Outside tmux, it creates or attaches
a per-directory session named like `tokenhud-codex-<key>`.

Shell wrapper:

```bash
codex() {
  tokenhud launch codex "$@"
}
```

Set `TOKENHUD_LAUNCH_TMUX=0` to bypass auto-tmux.
Set `TOKENHUD_TMUX_STATUS=0` if you want the launcher without the statusline.

## Shell Prompt

TokenHUD can print one line immediately above each new terminal prompt. The
prompt hook reads a small per-cwd cache file and refreshes it in the background
so a large session directory does not block your input line. The first prompt
for a directory generates the cache once in the foreground; later prompts
refresh only when the matching session JSONL has changed. Cache entries older
than 30 days are cleaned during refresh.

Bash:

```bash
eval "$(tokenhud init bash)"
```

Zsh:

```zsh
eval "$(tokenhud init zsh)"
```

Add the matching line to `~/.bashrc` or `~/.zshrc` if you want it enabled for
new terminals. Set `TOKENHUD_PROMPT=0` in a terminal to silence it temporarily.
Set `TOKENHUD_DEBUG=1` to write foreground/background refresh diagnostics to
`$TOKENHUD_CACHE_DIR/refresh.log`; the hook rotates that file once it grows
beyond roughly 200 KB.

## Style Examples

```text
balanced   TH codex:gpt-5.5 ▕████████░░▏ 80.7%  $ 0.127/7.50  cr 3.17cr/187cr  lim 9.0/13.0%  main +11
minimal    TH 80.7% $7.50 187cr main +11
ledger     TH codex last $0.127/3.17cr | session $7.50/187cr | in 6.27M out 45.2k
risk       TH ▕████████░░▏ 80.7% watch  $7.50  lim 9.0/13.0%  main +11
executive  TokenHUD | adapter codex | ctx 80.7% | session $7.50 / 187cr | limits 9.0%/13.0%
focus      TH 80.7% watch $7.50
ascii      TH codex:gpt-5.5 [########--] 80.7% $0.127/$7.50 main +11
```

More options and rationale live in [docs/style-gallery.md](docs/style-gallery.md).

## Roadmap

TokenHUD is the Codex adapter seed for a broader local-first AI CLI spend
ledger. The proposed multi-CLI path, adapter contract, alerting features,
pricing registry, and distribution plan are in
[docs/multi-cli-roadmap.md](docs/multi-cli-roadmap.md).

## tmux

Recommended: use `tokenhud launch <cli>`. That keeps TokenHUD scoped to the AI
CLI session instead of running a global `status-right` command in every tmux
pane.

Manual session-local status-right example:

```tmux
set -g status-interval 5
set -g status-right "#(TOKENHUD_STYLE=balanced ~/.local/bin/tokenhud status #{q:pane_current_path}) %H:%M"
```

Plugin-style entrypoint:

```tmux
set -g @tokenhud_style "risk"
set -g @tokenhud_adapter "codex"
# Optional. If omitted, TokenHUD leaves your existing status-interval alone.
set -g @tokenhud_interval "5"
set -g @tokenhud_right_length "180"
# Optional. Use "global" only if you explicitly want every tmux session to run it.
set -g @tokenhud_scope "session"
run-shell "/path/to/TokenHUD/tmux/tokenhud.tmux"
```

Legacy `@codexhud_*` options and `tmux/codexhud.tmux` remain supported.

## Pricing Notes

`tokenhud models` reads locally callable Codex models from `codex debug models`
and joins them with `~/.tokenhud/prices.json`. The price file has
`last_updated` and `stale_after_days`; JSON output exposes `pricing.status` and
`pricing.stale` separately, unknown models are labeled `unknown-model`, and
missing configs render cost as `n/a`.

Run `tokenhud prices-check` to inspect the active price file, freshness, source
URLs, and the manual refresh steps. TokenHUD does not auto-rewrite pricing data:
check the source URLs, edit `~/.tokenhud/prices.json`, update `last_updated`,
then run `tokenhud models` to inspect coverage. Set
`TOKENHUD_PRICES_CHECK_FETCH=1` if you also want lightweight URL reachability
probes.

`gpt-5.3-codex-spark` is intentionally mapped to `gpt-5.3-codex` pricing in the
default config as a provisional rule.

Reasoning output tokens are displayed, but cost is computed from `output_tokens`;
the script does not add reasoning tokens a second time. This matches observed
Codex session telemetry where `reasoning_output_tokens` is included within
`output_tokens`, not an extra billable bucket.

## Requirements

- Bash
- `jq`
- `git`
- GNU `find` or BSD/macOS `stat`
- Codex CLI with local session files under `~/.codex/sessions` for the Codex adapter

## Project Layout

```text
bin/tokenhud             main executable statusline script
bin/codexhud             compatibility alias
config/prices.json       default editable price config
tmux/tokenhud.tmux       tmux plugin-style entrypoint
tmux/codexhud.tmux       compatibility tmux entrypoint
docs/style-gallery.md    visual directions and examples
docs/naming.md           name search notes and alternatives
docs/multi-cli-roadmap.md multi-CLI adapter and spend-ledger roadmap
examples/tokenhud.json   sample JSON output shape
scripts/check.sh         local smoke checks
```

## Checks

```bash
./scripts/check.sh
```
