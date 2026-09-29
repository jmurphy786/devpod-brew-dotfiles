#!/usr/bin/env bash
# prefix+shift+m -- add a DevPod container to herdr: the container as a saved
# machine (its own sidebar section), and the repo it bind-mounts as the
# workspace its worktrees group under.
#
# Host only. DevPod already wrote a `Host <workspace>.devpod` entry per
# container to ~/.ssh/config; this picks one, so neither command has to be
# typed. Each container's herdr server keeps the workspace in its own
# session.json, so this runs once per container, not per session.
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
[ -f "$HOME/.ssh/config" ] || die "No ~/.ssh/config -- has devpod created any workspaces?"

# host <TAB> workdir (or "-") for every DevPod entry. --workdir is only in the
# ProxyCommand when the workspace was created with one.
entries=$(awk '
  /^Host [^ ]+\.devpod$/ { if (h != "") print h "\t" (w == "" ? "-" : w); h = $2; w = ""; next }
  /^Host / { if (h != "") print h "\t" (w == "" ? "-" : w); h = ""; w = ""; next }
  h != "" && /ProxyCommand/ && match($0, /--workdir "[^"]+"/) {
    w = substr($0, RSTART + 11, RLENGTH - 12)
  }
  END { if (h != "") print h "\t" (w == "" ? "-" : w) }
' "$HOME/.ssh/config")
[ -n "$entries" ] || die "No *.devpod hosts in ~/.ssh/config."

# Hide the ones that are already machines. The JSON shape is not documented,
# so look for the host as any quoted string in it rather than at a fixed path
# -- and without jq, which the host does not have.
saved=$("$HERDR" machine list --json 2>/dev/null | tr -d '\n')
rows=$(printf '%s\n' "$entries" | awk -F'\t' -v saved="$saved" '
  index(saved, "\"" $1 "\"") == 0 { printf "%s\t%s\n", $1, $2 }
')
[ -n "$rows" ] || { hold "Every DevPod container is already a machine."; exit 0; }

sel=$(printf '%s\n' "$rows" | column -t -s $'\t' \
      | fzf --prompt 'devpod> ' --height 100% --border none --no-preview \
            --header 'add a DevPod container as a herdr machine')
[ -n "$sel" ] || exit 0
host=$(printf '%s' "$sel" | awk '{print $1}')
workdir=$(printf '%s\n' "$rows" | awk -F'\t' -v h="$host" '$1 == h { print $2 }')
name=${host%.devpod}

printf 'checking ssh %s…\n' "$host"
if ! ssh -o BatchMode=yes -o ConnectTimeout=30 "$host" true 2>/dev/null; then
  status=$(devpod status "$name" 2>/dev/null)
  die "ssh $host failed. devpod status: ${status:-unknown}. Start it with: devpod up $name"
fi

# No --workdir: devpod ssh lands in the workspace folder, so ask it.
if [ "$workdir" = "-" ]; then
  workdir=$(ssh -o BatchMode=yes "$host" pwd 2>/dev/null)
fi
read -r -e -p "repo path in the container: " -i "$workdir" workdir
[ -n "$workdir" ] || die "No repo path."
read -r -e -p "sidebar label: " -i "$name" label
[ -n "$label" ] || die "No label."

# Interactive: it offers to install or update herdr on the remote and to pick
# a session there, which is why this is a popup and not a shell command.
echo
"$HERDR" machine add "$host" --label "$label" || die "herdr machine add failed."

"$HERDR" --machine "$label" workspace create \
  --cwd "$workdir" --label "${workdir##*/}" --focus >/dev/null \
  || die "Added the machine, but workspace create failed for '$workdir'."
