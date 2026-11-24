# Storage: scan helper and cleanup sources

The Storage panel shows where the space on `/` went and frees it through cleanups
you tick and confirm. Behind it:

- `scripts/storage-scan.py`: a read-only scan (`statvfs`, `du`, `btrfs filesystem df`)
  that prints one JSON object. It never deletes anything.
- `scripts/storage-sources.json`: the cleanup sources shipped with the shell.
- `Services/System/Storage.qml`: runs the helper and keeps the last result for QML.

## What the helper does

```
storage-scan.py --root                    free space only (instant)
storage-scan.py [--depth N]               free space, cleanup entries, size tree of ~
storage-scan.py --tree PATH [--depth N]   size tree of one folder (Explore drill-down)
```

Options: `--timeout S` (default 25) bounds the whole scan; a scan that runs out of
time reports what it has with `"partial": true`. `--sources FILE` adds a source
file (repeatable). `--no-user-sources` skips your config file. `--mount` picks
another mount point for the free-space figures.

The shell reads free space at startup and every 5 minutes (`--root`). The full
scan runs only when you press Rescan in the panel: one `du` walk of `$HOME`
builds the size tree while, alongside it, each entry's folders are sized
(`du -s`, up to 6 at a time) and each `children` source lists its base.

## Free space and alert levels

`root` holds `size`, `used`, `free`, `free_pct`, `used_pct` and `fstype`. On btrfs,
`free` is the smaller of `df` and btrfs' own estimate, and two more fields appear:

- `btrfs_metadata_free`: metadata space left in the allocated chunks.
- `btrfs_unallocated`: device space not yet given to data or metadata.

The bar widget's level uses the same rules as the dotfiles `disk-alert.sh`:

| Level | When |
|---|---|
| warn | free ≤ `storage.warnPct` (default 15) % |
| critical | free ≤ `storage.critPct` (default 8) %, or metadata has under 1 GiB free and less than 1 GiB is unallocated |

Both thresholds are keys in `~/.config/archeotech/config.json`, separate from
the dotfiles `disk-alert.conf`.

## Cleanup sources

A source is one JSON object. The helper reads, in order:

1. `scripts/storage-sources.json` (shipped),
2. `${XDG_CONFIG_HOME:-~/.config}/archeotech/storage-sources.json` (yours),
3. any `--sources` files.

A later source with the same `id` replaces the earlier one completely, and
`{"id": "docker", "disabled": true}` hides a shipped source. Each file is either
`{"sources": [...]}` or a plain list. A bad file or source does not stop the
scan; it shows in the result's `errors`.

### Fields

| Field | Required | Meaning |
|---|---|---|
| `id` | yes | Unique name; a later source with the same id replaces this one |
| `label` | yes | Row title. `{name}`, `{path}` and `{mtime}` are filled from the first path |
| `tier` | yes | `safe` (rebuilt or downloaded again on demand; ticked by default) or `review` (look before deleting; unticked by default) |
| `action` | yes | `remove` (`rm -rf`), `trash` (`gio trash`, recoverable), `command` (run `command`) or `open` (only opens the folder; nothing runs) |
| `path` / `paths` | unless `action` is `command` | Folder(s). `~`, `$VAR` and `${VAR}` expand; a path with an unset variable is skipped; a path that does not exist hides the source |
| `glob` | no | `true`: `path` is a glob pattern. Each match is its own row (id `<id>:<name>`) unless `group` is `true` |
| `command` | for `command` | Shell command. `{path}` runs it once per path; `{paths}` passes them all; neither runs it once |
| `root` | no | `true`: the command needs root (see Privileges) |
| `requires` | no | A program name; the source is hidden when it is not installed |
| `cost` | no | What deleting costs, shown under the row (`{name}`, `{path}`, `{mtime}` fill in) |
| `detail` | no | Second line of the row (default: the path) |
| `detail_command` | no | Shell command whose output replaces `detail` (e.g. a snapshot count) |
| `size` | no | `"none"`: do not size it (shown without a size, unticked by default) |
| `upto` | no | `true`: the size is an upper bound (the command keeps part of it) |
| `checked` | no | Override the default tick (a safe row is ticked when it has a size above 0) |
| `children` | no | Size each folder inside `path` instead (`remove` and `trash` only): `{"min_bytes": N, "max": 8, "group": true, "exclude": [paths]}`. `group: false` gives one row per folder. `path` must be `~/.cache`, `~/.local/state` (or inside them) or a folder inside `~/.local/share` |
| `disabled` | no | `true`: hide this id |

### Safety rules

- Nothing personal is offered. The guard covers `remove` and `trash` sources and
  any `command` that is given the path (`{path}`, `{paths}`). It refuses, and lists
  under `rejected` with the reason:
  - `$HOME` or one of its parents, another user's home, a system folder (`/usr`,
    `/etc`, `/var`, …);
  - an XDG user folder (Documents, Downloads, Pictures, Projects from
    `user-dirs.dirs`, …) or anything inside one;
  - anything in `~/.config`, `~/.ssh`, `~/.gnupg`, `~/.password-store`, `~/.pki`,
    `~/.mozilla` or `~/.local/bin`;
  - `~/.cache`, `~/.local`, `~/.local/share` and `~/.local/state` themselves
    (folders inside them are allowed);
  - a `children` source whose base is not a cache area (see Fields).

  Use `action: "open"` for a personal folder you want listed (the shipped Downloads row).
- A folder is counted once. A path claimed by one source, and any path inside
  it or holding it, is skipped by every later one, and a `children` source skips any folder that holds, or sits inside,
  another source's path (`~/.cache/paru` is not offered as an app cache because
  `paru` owns `~/.cache/paru/clone`).
- Each entry carries the exact `commands`; paths are shell-quoted (also in a
  `detail_command`, which runs during the scan). The panel shows the commands
  before anything runs.

### Privileges

Entries with `"root": true` (pacman cache, journal, snapper) run as root. The panel
runs all root commands of one cleanup in a single `pkexec sh -c '…'` call, so you
answer one polkit prompt per cleanup, never a terminal `sudo`. User commands run
as you.

### Example: your own sources

`~/.config/archeotech/storage-sources.json`:

```json
{
  "sources": [
    {
      "id": "old-backup",
      "label": "Old backup {name}",
      "path": "~/arch-backup-*",
      "glob": true,
      "tier": "review",
      "action": "trash",
      "cost": "Copied on {mtime}; it goes to the Trash"
    },
    {"id": "docker", "disabled": true}
  ]
}
```

Rescan in the panel to see them; no shell change or reload is needed.

## Output reference

```
{ "version": 1, "generated": "2026-11-24T10:00:00", "elapsed": 4.3, "partial": false,
  "root": { … },
  "entries": [ { "id", "source", "label", "detail", "cost", "tier", "action", "root",
                 "bytes" (null = unknown), "approx", "upto", "paths", "commands",
                 "checked", "user" } ],
  "rejected": [ { "id", "path", "reason" } ],
  "errors": [ "…" ],
  "tree": { "name", "path", "bytes", "kind", "tier"?, "children"?, "complete" } }
```

Tree nodes: `kind` is `dir`, `file` (the top folder's own largest files), `more`
(the folders past the kept ones, one box), or `files` (the loose files of a
folder). `tier` colours the size map: `safe` or `review` for a source's folder,
`personal` for a user folder. Each folder keeps 24, 12, then 8 children per level.
