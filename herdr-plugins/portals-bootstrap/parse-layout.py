#!/usr/bin/env python3
"""Read the `windows:` block out of a workmux config.

Keeps .workmux.yaml as the single definition of the per-worktree layout, so a
worktree opened through herdr gets the same tabs as one opened through workmux
and neither setup has to be edited to change the other.

Only the shape workmux actually uses is supported -- a list of windows, each
with a `name` and an optional `panes` list whose entries carry `command` and
`focus`.  Anything richer needs a real YAML parser, and pyyaml is not
installed here.

Emits one TSV line per window: name <TAB> command <TAB> focus(0|1)

With --symlinks, emits the `files.symlink` entries instead, one per line --
the paths workmux links from the main worktree into every new one.
"""
import re
import sys

def parse(text):
    windows = []
    in_windows = False
    cur = None
    pane = None
    for raw in text.splitlines():
        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip())
        body = line.strip()

        if indent == 0:
            # A new top-level key ends the windows block.
            in_windows = body.startswith("windows:")
            continue
        if not in_windows:
            continue

        if body.startswith("- name:"):
            cur = {"name": body[len("- name:"):].strip().strip("'\""),
                   "command": "", "focus": False}
            windows.append(cur)
            pane = None
        elif cur is None:
            continue
        elif body.startswith("- command:"):
            # First pane of the window wins; workmux splits later ones, which
            # this layout never uses.
            pane = cur if not cur["command"] else None
            if pane is not None:
                pane["command"] = body[len("- command:"):].strip().strip("'\"")
        elif body.startswith("focus:") and pane is not None:
            pane["focus"] = body[len("focus:"):].strip().lower() in ("true", "yes", "1")
    return windows

def parse_symlinks(text):
    links = []
    section = None
    for raw in text.splitlines():
        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip())
        body = line.strip()

        if indent == 0:
            section = "files" if body.startswith("files:") else None
        elif section == "files" and not body.startswith("-"):
            # A key under files: -- only symlink: carries the list we want.
            section = "symlink" if body.startswith("symlink:") else "files"
        elif section == "symlink" and body.startswith("-"):
            entry = body[1:].strip().strip("'\"")
            if entry:
                links.append(entry)
    return links

def main():
    args = sys.argv[1:]
    symlinks = bool(args) and args[0] == "--symlinks"
    if symlinks:
        args = args[1:]
    for path in args:
        try:
            with open(path, encoding="utf-8") as fh:
                text = fh.read()
        except OSError:
            continue
        if symlinks:
            links = parse_symlinks(text)
            if links:
                print("\n".join(links))
                return 0
            continue
        windows = parse(text)
        if windows:
            for w in windows:
                print("\t".join([w["name"], w["command"], "1" if w["focus"] else "0"]))
            return 0
    return 1

if __name__ == "__main__":
    sys.exit(main())
