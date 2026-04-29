#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bin="$repo_dir/bin/tokenhud"
compat_bin="$repo_dir/bin/codexhud"
export TOKENHUD_PRICE_FILE="$repo_dir/config/prices.json"

bash -n "$bin"
bash -n "$compat_bin"
bash -n "$repo_dir/install.sh"
bash -n "$repo_dir/tmux/tokenhud.tmux"
bash -n "$repo_dir/tmux/codexhud.tmux"

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$bin" "$compat_bin" "$repo_dir/install.sh" "$repo_dir/tmux/tokenhud.tmux" "$repo_dir/tmux/codexhud.tmux"
elif [ "${TOKENHUD_REQUIRE_SHELLCHECK:-${CODEXHUD_REQUIRE_SHELLCHECK:-0}}" = "1" ]; then
  printf 'check: shellcheck is required but not installed\n' >&2
  exit 127
else
  printf 'check: shellcheck not installed; skipping shell lint\n' >&2
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

stub_bin="$tmp_dir/bin"
mkdir -p "$stub_bin"
cat >"$stub_bin/codex" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "debug" ] && [ "${2:-}" = "models" ]; then
  cat <<'JSON'
{
  "models": [
    { "slug": "gpt-5.5", "supported_in_api": true, "visibility": "list" },
    { "slug": "gpt-5.4", "supported_in_api": true, "visibility": "list" },
    { "slug": "gpt-5.4-mini", "supported_in_api": true, "visibility": "list" },
    { "slug": "gpt-5.3-codex", "supported_in_api": true, "visibility": "list" },
    { "slug": "gpt-5.2", "supported_in_api": true, "visibility": "list" },
    { "slug": "codex-auto-review", "supported_in_api": true, "visibility": "hide" },
    { "slug": "gpt-5.3-codex-spark", "supported_in_api": false, "visibility": "list" }
  ]
}
JSON
  exit 0
fi

printf 'stub codex: unsupported arguments\n' >&2
exit 2
STUB
chmod +x "$stub_bin/codex"
export PATH="$stub_bin:$PATH"

"$bin" styles >/dev/null
"$bin" adapters >/dev/null
"$bin" models >/dev/null
"$bin" prices-check >/dev/null
TOKENHUD_LAUNCH_TMUX=0 "$bin" launch true >/dev/null
"$bin" init bash >/dev/null
"$bin" init zsh >/dev/null
"$compat_bin" --version >/dev/null

cache_key="$("$bin" cache-key /tmp/tokenhud-target)"
case "$cache_key" in
  ????????????????) ;;
  *)
    printf 'expected a 16-character cache key, got: %s\n' "$cache_key" >&2
    exit 1
    ;;
esac

init_bash="$("$bin" init bash)"
case "$init_bash" in
  *"tokenhud cache-key \"\$PWD\""*) ;;
  *)
    printf 'expected init hook to use tokenhud cache-key\n' >&2
    exit 1
    ;;
esac
case "$init_bash" in
  *'refresh.log'*) ;;
  *)
    printf 'expected init hook to include TOKENHUD_DEBUG refresh logging\n' >&2
    exit 1
    ;;
esac

codex_home="$tmp_dir/codex-home"
session_dir="$codex_home/sessions/2026/04/29"
mkdir -p "$session_dir"

cat >"$codex_home/config.toml" <<'TOML'
model = "gpt-5.5" # root model wins

[profile.other]
model = "not-the-root-model"
TOML

target_session="$session_dir/rollout-target.jsonl"
other_session="$session_dir/rollout-other.jsonl"

cat >"$target_session" <<'JSONL'
{"type":"session_meta","payload":{"id":"target-session","timestamp":"2026-04-29T01:00:00.000Z","cwd":"/tmp/tokenhud-target","originator":"codex-tui","cli_version":"0.125.0","source":"cli","model_provider":"openai","model":"gpt-5.4"}}
this is not json yet
{"type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":1000,"cached_input_tokens":500,"output_tokens":100,"reasoning_output_tokens":25,"total_tokens":500},"total_token_usage":{"input_tokens":2000,"cached_input_tokens":1000,"output_tokens":200,"reasoning_output_tokens":50,"total_tokens":2200},"model_context_window":2000}}}
JSONL

cat >"$other_session" <<'JSONL'
{"type":"session_meta","payload":{"id":"other-session","timestamp":"2026-04-29T01:01:00.000Z","cwd":"/tmp/tokenhud-other","originator":"codex-tui","cli_version":"0.125.0","source":"cli","model_provider":"openai"}}
{"type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":400,"cached_input_tokens":0,"output_tokens":100,"reasoning_output_tokens":10,"total_tokens":500},"total_token_usage":{"input_tokens":400,"cached_input_tokens":0,"output_tokens":100,"reasoning_output_tokens":10,"total_tokens":500},"model_context_window":1000},"rate_limits":{"primary":{"used_percent":12,"resets_at":1777428000,"window_minutes":300},"secondary":{"used_percent":34,"resets_at":1777430000,"window_minutes":10080},"plan_type":"pro"}}}
JSONL

touch -t 202604290100.00 "$target_session"
touch -t 202604290101.00 "$other_session"

for style in balanced minimal ledger risk executive focus ascii; do
  CODEX_HOME="$codex_home" TOKENHUD_STYLE="$style" "$bin" tmux /tmp/tokenhud-target >/dev/null
done

json_for_target="$(CODEX_HOME="$codex_home" "$bin" json /tmp/tokenhud-target)"
printf '%s\n' "$json_for_target" | jq -e '
  .product == "TokenHUD"
  and .adapter == "codex"
  and .session.id == "target-session"
  and .model == "gpt-5.4"
  and .context.used_percentage == 25
  and .cost.session_usd != "n/a"
  and .pricing.status == "configured"
  and .pricing.stale == false
  and .pricing.last_updated == "2026-04-29"
' >/dev/null

tmux_for_target="$(CODEX_HOME="$codex_home" "$bin" tmux /tmp/tokenhud-target)"
case "$tmux_for_target" in
  *'lim n/a/n/a%'*) ;;
  *)
    printf 'expected missing rate limits to render as n/a, got: %s\n' "$tmux_for_target" >&2
    exit 1
    ;;
esac

json_for_latest="$(CODEX_HOME="$codex_home" "$bin" json)"
printf '%s\n' "$json_for_latest" | jq -e '.session.id == "other-session"' >/dev/null

unknown_model="$(CODEX_HOME="$codex_home" TOKENHUD_MODEL="unknown-test-model" "$bin" json /tmp/tokenhud-target)"
printf '%s\n' "$unknown_model" | jq -e '
  .pricing.status == "unknown-model"
  and .cost.session_usd == "n/a"
' >/dev/null

stale_prices="$tmp_dir/stale-prices.json"
jq '.last_updated = "2000-01-01"' "$repo_dir/config/prices.json" >"$stale_prices"
stale_model="$(CODEX_HOME="$codex_home" TOKENHUD_PRICE_FILE="$stale_prices" "$bin" json /tmp/tokenhud-target)"
printf '%s\n' "$stale_model" | jq -e '
  .pricing.status == "configured"
  and .pricing.stale == true
' >/dev/null

cache_file="$tmp_dir/prompt-cache.txt"
touch "$cache_file"
CODEX_HOME="$codex_home" TOKENHUD_CACHE_FILE="$cache_file" "$bin" cache-refresh /tmp/tokenhud-target
test -s "$cache_file"
CODEX_HOME="$codex_home" TOKENHUD_CACHE_FILE="$cache_file" "$bin" cache-refresh /tmp/tokenhud-target
test -s "$cache_file"

custom_home="$tmp_dir/custom-home"
mkdir -p "$custom_home"
cache_from_home="$(
  TOKENHUD_HOME="$custom_home" "$bin" init bash \
    | awk '/TOKENHUD_CACHE_DIR:-/ { print; exit }'
)"
expected_cache_expr="\${TOKENHUD_HOME:-\${CODEXHUD_HOME:-\$HOME/.tokenhud}}/cache"
case "$cache_from_home" in
  *"$expected_cache_expr"*) ;;
  *)
    printf 'expected init hook to honor TOKENHUD_HOME, got: %s\n' "$cache_from_home" >&2
    exit 1
    ;;
esac

legacy_cache_from_home="$(
  CODEXHUD_HOME="$custom_home" "$bin" init bash \
    | awk '/TOKENHUD_CACHE_DIR:-/ { print; exit }'
)"
case "$legacy_cache_from_home" in
  *'CODEXHUD_HOME'*) ;;
  *)
    printf 'expected init hook to honor legacy CODEXHUD_HOME, got: %s\n' "$legacy_cache_from_home" >&2
    exit 1
    ;;
esac

printf 'ok\n'
