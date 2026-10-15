#!/usr/bin/env python3
"""Find shell pixels that compositor layer blur would turn into visible patches.

mango/scenefx blurs behind every pixel of a shell surface whose alpha is above 0,
at full strength, whatever the alpha (adr_035). A faint pixel (a soft shadow, a
glow, a transparent-but-not-quite margin, a surface caught mid-fade) therefore
shows a blurred patch that the surface itself barely covers.

Pass 1 (always, pixman): renders each state twice with scripts/shot.sh over a
black and a white wallpaper and recovers each pixel's alpha:
    over black: a*C        over white: a*C + (1 - a)*255   ->   a = 1 - (W - B) / 255
Pixels with 0 < alpha < --faint that form a region thicker than an anti-aliased
edge (they survive a 3x3 erosion) are reported.

Pass 2 (--app, GPU, needs a readable /dev/dri render node): opens a kitty window
behind the state and renders it with mango layer blur off and on (--mode xray|
windows picks blur_optimized). Wherever pass 1 says the shell draws nothing
(alpha < 0.02), blur must change nothing; pixels that differ there (more than
--tol per channel) are blur artifacts: fringes, ghost borders, whole-window blur.

    scripts/blur-scan.py [--root <checkout>] [--out <dir>] [--app] [--mode xray|windows]
                         [--app-theme dark|light] [state ...]

States are shot.sh --state values ("" = the plain bar) plus "toast" and "osd".
Exit 1 if any state has findings. Masks per state land in --out.
"""
import argparse
import pathlib
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

DEFAULT_STATES = ["", "dashboard", "launcher", "settings", "notifications", "media",
                  "popup:hover", "popup:calendar", "popup:wifi", "popup:bt", "popup:strip",
                  "toast", "osd"]

# Shell IPC that opens each state from inside the nested session (--exec), so it
# can run after the app window maps (a panel opened first may close on focus).
def drive(state):
    if state == "toast":
        return 'notify-send -t 1500 first; sleep 9; notify-send -t 0 "Claude Code" "Claude needs your permission"; sleep 3'
    if state == "osd":
        return "qs ipc --pid $QSPID call osd volume; sleep 0.6"
    if state.startswith("popup:"):
        return f"qs ipc --pid $QSPID call popup open {state[6:]}; sleep 1"
    if state.startswith("settings:"):
        return f"qs ipc --pid $QSPID call settings openPane {state[9:]}; sleep 1.5"
    if state in ("notifications",):
        return "qs ipc --pid $QSPID call notifications open; sleep 1.5"
    if state:
        return f"qs ipc --pid $QSPID call {state} open; sleep 1.5"
    return ":"


APP = {
    "dark":  "kitty -o background_opacity=0.5 -o cursor_blink_interval=0",
    "light": "kitty -o background_opacity=1 -o background=#eff1f5 -o foreground=#4c4f69 -o cursor_blink_interval=0",
}


def shot(root, args, out, extra):
    cmd = [str(root / "scripts" / "shot.sh"), "--root", str(root),
           "--set", f'appearance.glass="{args.preset}"', "-w", "8"] + extra
    subprocess.run(cmd + [str(out)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return np.asarray(Image.open(out).convert("RGB"), dtype=np.float32)


def erode(mask):
    """3x3 erosion: keep pixels whose 8 neighbours are all set."""
    m = np.pad(mask, 1)
    out = np.ones_like(mask)
    for dy in (0, 1, 2):
        for dx in (0, 1, 2):
            out &= m[dy:dy + mask.shape[0], dx:dx + mask.shape[1]]
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--root", default=str(pathlib.Path(__file__).resolve().parents[1]))
    ap.add_argument("--out", default="")
    ap.add_argument("--preset", default="glass", help="glass preset to render (solid = shadows on, a positive control)")
    ap.add_argument("--faint", type=float, default=0.5, help="alpha below this counts as faint")
    ap.add_argument("--app", action="store_true", help="also diff GPU renders with an app window behind")
    ap.add_argument("--mode", choices=["xray", "windows"], default="xray")
    ap.add_argument("--app-theme", choices=["dark", "light"], default="dark")
    ap.add_argument("--tol", type=float, default=12, help="per-channel difference that counts as changed")
    ap.add_argument("states", nargs="*")
    args = ap.parse_args()
    root = pathlib.Path(args.root).resolve()
    out = pathlib.Path(args.out or tempfile.mkdtemp(prefix="blur-scan."))
    out.mkdir(parents=True, exist_ok=True)
    black, white = out / "black.png", out / "white.png"
    Image.new("RGB", (1280, 720), (0, 0, 0)).save(black)
    Image.new("RGB", (1280, 720), (255, 255, 255)).save(white)
    app = APP[args.app_theme] + ' sh -c "ls -la --color=always /usr/bin | head -400; sleep 60" >/dev/null 2>&1 & sleep 3; '

    bad = 0
    for state in (args.states or DEFAULT_STATES):
        name = state.replace(":", "-") or "bar"
        ex = ["-w", "6", "--exec", drive(state)]
        b = shot(root, args, out / f"{name}-black.png", ["--wallpaper", str(black)] + ex)
        w = shot(root, args, out / f"{name}-white.png", ["--wallpaper", str(white)] + ex)
        alpha = 1.0 - (w - b).mean(axis=2) / 255.0
        faint = (alpha > 0.02) & (alpha < args.faint)
        region = erode(faint)
        n = int(region.sum())
        mask = np.zeros(alpha.shape + (3,), np.uint8)
        mask[..., :] = (b / 4).astype(np.uint8)          # dim render for orientation
        mask[faint] = (120, 120, 0)                      # faint, any width (edges too)
        mask[region] = (255, 0, 0)                       # faint and thicker than an edge
        line = f"{name:16s} faint {n:6d}"
        if args.app:
            gpu = ["--renderer", "gles2", "-w", "6", "--mango-line",
                   f"blur_optimized={0 if args.mode == 'windows' else 1}", "--exec", app + drive(state)]
            off = shot(root, args, out / f"{name}-app-off.png", gpu + ["--mango-line", "blur_layer=0"])
            on = shot(root, args, out / f"{name}-app-on.png", gpu + ["--mango-line", "blur_layer=1"])
            outside = alpha < 0.02
            changed = np.abs(on - off).max(axis=2) > args.tol
            art = outside & changed
            a = int(art.sum())
            mask[art] = (255, 0, 255)                    # blur where the shell draws nothing
            line += f"  artifacts {a:6d}"
            n += a
            if a:
                ys, xs = np.nonzero(art)
                line += f" box x{xs.min()}-{xs.max()} y{ys.min()}-{ys.max()}"
        Image.fromarray(mask).save(out / f"{name}-mask.png")
        bad += bool(n)
        print(f"{'FAIL' if n else 'ok  '}  {line}", flush=True)
    print(f"masks: {out}")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
