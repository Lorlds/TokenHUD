#!/usr/bin/env bash
set -euo pipefail

current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
binary="$(tmux show-option -gqv @tokenhud_binary)"
[ -z "$binary" ] && binary="$(tmux show-option -gqv @codexhud_binary)"
[ -z "$binary" ] && binary="$current_dir/../bin/tokenhud"

style="$(tmux show-option -gqv @tokenhud_style)"
[ -z "$style" ] && style="$(tmux show-option -gqv @codexhud_style)"
[ -z "$style" ] && style="balanced"

adapter="$(tmux show-option -gqv @tokenhud_adapter)"
[ -z "$adapter" ] && adapter="$(tmux show-option -gqv @codexhud_adapter)"
[ -z "$adapter" ] && adapter="codex"

interval="$(tmux show-option -gqv @tokenhud_interval)"
[ -z "$interval" ] && interval="$(tmux show-option -gqv @codexhud_interval)"
case "$interval" in
  *[!0-9]*) interval="" ;;
esac

length="$(tmux show-option -gqv @tokenhud_right_length)"
[ -z "$length" ] && length="$(tmux show-option -gqv @codexhud_right_length)"
case "$length" in
  ''|*[!0-9]*) length="180" ;;
esac

scope="$(tmux show-option -gqv @tokenhud_scope)"
[ -z "$scope" ] && scope="$(tmux show-option -gqv @codexhud_scope)"
[ -z "$scope" ] && scope="session"
case "$scope" in
  global) option_scope=(-g) ;;
  *) option_scope=() ;;
esac

existing="$(tmux show-option "${option_scope[@]}" -qv status-right)"
printf -v segment '#(TOKENHUD_ADAPTER=%q TOKENHUD_STYLE=%q %q status #{q:pane_current_path})' "$adapter" "$style" "$binary"

[ -z "$interval" ] || tmux set-option "${option_scope[@]}" status-interval "$interval" >/dev/null
tmux set-option "${option_scope[@]}" status-right-length "$length" >/dev/null
case "$existing" in
  *tokenhud*|*codexhud*) ;;
  *) tmux set-option "${option_scope[@]}" status-right "$segment $existing" >/dev/null ;;
esac
