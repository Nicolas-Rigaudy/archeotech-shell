# Golden diagnosis (2026-10-21)

Why `scripts/golden.sh` fails on main (`a52d1a9`), grouped by cause. Nothing
here was regenerated: the goldens stay as committed until blur is validated.

## Run

`scripts/golden.sh --root .` from a worktree of `a52d1a9`, default
`THRESHOLD=40`, `FUZZ=3%`, pixman renderer: **16/25 fail** (an earlier, interrupted
run counted 15; `wallpaper-light` sits at 46 px, just over the line).

To separate code changes from machine changes, the goldens' own commit
(`6c7b741`, every golden PNG dates from it or earlier) was rendered on today's
stack the same way, and its renders were diffed against main's with the same
masks.

| Scenario | main vs golden | `6c7b741` vs golden | main vs `6c7b741` |
|---|---|---|---|
| dashboard-dark | 111 FAIL | 111 FAIL | 0 |
| dashboard-light | 107 FAIL | 77 FAIL | 30 |
| dashboard-flat | 109 FAIL | 108 FAIL | 0 |
| dashboard-grimdark | 182 FAIL | 171 FAIL | 10 |
| media-dark | 75 FAIL | 62 FAIL | 12 |
| media-light | 82 FAIL | 40 ok | 42 |
| media-flat | 107 FAIL | 95 FAIL | 12 |
| wallpaper-light | 46 FAIL | 15 ok | 30 |
| settings-dark | 216 FAIL | 216 FAIL | 0 |
| settings-light | 227 FAIL | 196 FAIL | 31 |
| settings-flat | 229 FAIL | 229 FAIL | 0 |
| notifications-dark | 42 FAIL | 41 FAIL | 0 |
| notifications-light | 136 FAIL | 26 ok | 110 |
| notifications-flat | 76 FAIL | 77 FAIL | 0 |
| editmode-light | 90 FAIL | 95 FAIL | 5 |
| bar-*, launcher-*, wallpaper-dark/flat, editmode-dark/flat | ok (0-34) | ok | 0-30 |

## Causes

### 1. Font / render stack drift: 12 failures, regenerate

The goldens were committed on 2026-10-15 before 16:10; the same evening
(23:37) the machine upgraded qt6-base and qt6-declarative 6.11.2 -> 6.12.0,
harfbuzz 14.5.1 -> 14.6.0, librsvg 2.62 -> 2.63, quickshell 0.3.1 -> 0.3.2 and
mangowm 0.17.5 -> 0.18.1.

The golden commit itself fails these 12 on today's stack with the same pixel
counts as main, so the code is not the cause. Every diff cluster sits on glyph
edges (tile labels, settings headers and rows, the media empty state, the
edit-mode segmented control) or on the grimdark bar icons. Zoomed side by side
they look the same: the change is in anti-aliasing (max channel delta about
70/255 on dark, 140/255 on light), and no glyph, layout or colour moves. The
largest per-pixel deltas in `dashboard-grimdark` are the clock digits spilling
past the clock mask edge (x 533 and 734), which are dynamic anyway.

Scenarios: dashboard-dark/light/flat/grimdark, media-dark/flat,
settings-dark/light/flat, notifications-dark/flat, editmode-light.

### 2. Patched scenefx (scenefx-coverage) on this machine: +3 failures, regenerate after the blur review

`a4506d8` turns the blur-safe workarounds off when coverage-weighted blur is
active; `a6e3015` detects it by checking that every running mango maps
`libscenefx` and that `/usr/share/scenefx/coverage-blur` exists. With the
`scenefx-coverage` package installed system-wide (0.5-2, 2026-10-21), the
nested headless mango that `shot.sh` starts maps the patched library too, so
the headless shell reports coverage blur, `blurSafe` goes false, and:

- outer shadows come back (accent buttons, the active bottom tab, panels);
- outer panel edges are smooth again instead of crisp.

This is the intended behaviour of those commits, not a regression, but it makes
the goldens depend on whether scenefx-coverage is installed. It shows only in
light mode (the soft light shadow over a pale panel crosses `FUZZ`; in dark it
stays below 3 %; flat draws no shadows). It pushes media-light, wallpaper-light
and notifications-light over the threshold and adds 30 px to dashboard-light
and settings-light.

Before regenerating, decide which headless state the goldens record: either
pin it in `golden.sh` (`appearance.coverageBlur` on or off for `--fresh`
renders) or accept that goldens follow the machine's scenefx package.

### 3. mango 0.18 renamed config keys: 0 failures today

Before `3a8fbb5` and `25f613b`, `shot.sh` wrote 0.17 keys and the nested mango
0.18 rejected them, so renders could fail outright. On main every scenario
renders; no frame shows a key-related difference.

### 4. Theme changes: 0 failures

`e5bbe78` / `aae26bf` (Blur-mode panel alphas) only apply with
`appearance.glassBlur = windows`; `--fresh` renders do not use it, and main vs
`6c7b741` in dark is 0 px on every scenario.

### 5. Real regressions: none found

Every masked difference between main and the golden commit is explained by
cause 2; everything else also fails on the golden commit itself.

## Recommendation

- After the owner validates blur (and picks the coverage-blur state for
  headless renders): `scripts/golden.sh --update` for the 16 failing scenarios
  (the passing ones can stay), review the new PNGs, commit them with the blur
  work.
- Optional hardening: the 12 stack-drift failures sit at 41-229 px; a glyph
  anti-aliasing change after a Qt/harfbuzz upgrade will keep tripping
  `THRESHOLD=40`. Regenerating after each toolkit upgrade is the cheap answer.

## Evidence

Expected / actual / diff PNGs (full frame, masked, plus a zoomed strip) for
`settings-dark` (cause 1) and `notifications-light` (causes 1 + 2) are kept
outside the repo, with the main-vs-`6c7b741` masked renders.
