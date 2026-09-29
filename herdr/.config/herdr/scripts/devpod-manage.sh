#!/usr/bin/env bash
# prefix+shift+e -- rename, disable/enable or remove a saved herdr machine.
#
# Host only, like devpod-add.sh. herdr has no binding for this, and a custom
# command cannot act on "the selected machine": it runs on the selected
# server, and herdr does not hand it the machine id. So this lists the saved
# machines and acts on the one you pick.
#
# Removing a machine only forgets the host's saved connection. The container,
# its herdr server and the workspace it keeps are untouched, so
# prefix+shift+m brings it back as it was.
set -uo pipefail

case ":$PATH:" in
  *:/home/linuxbrew/.linuxbrew/bin:*) ;;
  *) PATH="/home/linuxbrew/.linuxbrew/bin:$PATH" ;;
esac
HERDR="${HERDR_BIN_PATH:-herdr}"

hold() {
  [ -n "${1:-}" ] && printf '%s\n' "$1"
  printf '\n[any key to close] '
  read -rsn1 _ 2>/dev/null || true
  echo
}
die() { printf '%s\n' "$*" >&2; hold ""; exit 1; }

command -v devpod >/dev/null 2>&1 \
  || die "No devpod here. Select the Local machine in the sidebar and run this again."

# id <TAB> label <TAB> ssh target <TAB> remote session <TAB> enabled|disabled
machines=$("$HERDR" machine list 2>/dev/null | awk -F'\t' 'NF >= 5')
[ -n "$machines" ] || { hold "No saved machines."; exit 0; }

# The id stays in field 1 for the lookup below but is not shown.
sel=$(printf '%s\n' "$machines" \
      | fzf --delimiter $'\t' --with-nth 2,3,5 --prompt 'machine> ' \
            --height 100% --border none --no-preview \
            --header 'label  target  status')
[ -n "$sel" ] || exit 0
IFS=$'\t' read -r id label target _session status <<<"$sel"

toggle=disable
[ "$status" = "disabled" ] && toggle=enable

action=$(printf '%s\n' rename "$toggle" remove \
         | fzf --prompt "$label> " --height 100% --border none --no-preview \
               --header "$label ($target, $status)")
[ -n "$action" ] || exit 0

case "$action" in
  rename)
    read -r -e -p "new label: " -i "$label" new
    [ -n "$new" ] && [ "$new" != "$label" ] || exit 0
    # id first: 0.9.2 rejects `--label <x> <id>` despite its --help.
    "$HERDR" machine rename "$id" --label "$new" >/dev/null \
      || die "herdr machine rename failed."
    echo "renamed $label -> $new"
    ;;
  enable|disable)
    "$HERDR" machine "$action" "$id" >/dev/null \
      || die "herdr machine $action failed."
    echo "${action}d $label"
    ;;
  remove)
    echo "Remove $label ($target)?"
    echo "The container and its workspace are kept; prefix+shift+m re-adds it."
    read -r -p "[y/N] " yes
    [ "$yes" = y ] || [ "$yes" = Y ] || exit 0
    "$HERDR" machine remove "$id" >/dev/null \
      || die "herdr machine remove failed."
    echo "removed $label"
    ;;
esac
