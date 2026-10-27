#!/usr/bin/env python3
"""Reproduce what the owner sees on their desk, headless, and zoom into it.

Drives scripts/shot.sh (fully isolated nested mango) with the owner's setup:
their output size, their current wallpaper, the GPU renderer and mango's layer
blur, an app window behind the shell, then a scripted sequence of pointer and
shell actions, and finally an upscaled contact sheet of chosen regions.

    scripts/desk-check.py [--root <checkout>] [--size 1920x1200] [--wallpaper <img>]
                          [--glass glass|solid] [--blur xray|windows|off]
                          [--app dark|light|none] [--zoom X,Y,W,H ...] [--scale 6]
                          --out <png> [step ...]

Steps run in order inside the nested session:
    hover:X,Y            move the pointer to X,Y (absolute) and wiggle so hover fires
    click:X,Y            hover, then left click
    ipc:<target>.<fn>[:arg]   qs ipc call on the nested shell (by --pid)
    set:<key>=<json>     edit the nested config.json (the shell hot-reloads it),
                         e.g. set:appearance.glass="solid"
    notify:<text>        notify-send a toast (stays until dismissed)
    sleep:<seconds>
    burst:<prefix>:<n>:<gap>:<cmd>   run <cmd> and grab n frames <gap> s apart (<prefix>-NN.ppm)
The capture follows the last step. --zoom regions (screen pixels) are cropped,
upscaled with nearest-neighbour and stacked next to each other in <out>-zoom.png.
--wallpaper defaults to what awww shows on the owner's first output (read-only query).
"""
import argparse
import json
import pathlib
import re
import shlex
import shutil
import subprocess
import sys
import tempfile

from PIL import Image

APP = {
    "dark":  "kitty -o background_opacity=0.5 -o cursor_blink_interval=0",
    "light": "kitty -o background_opacity=1 -o background=#eff1f5 -o foreground=#4c4f69 -o cursor_blink_interval=0",
}


def live_wallpaper():
    """The image awww shows on the owner's first output (query only, changes nothing)."""
    try:
        out = subprocess.run(["awww", "query"], capture_output=True, text=True, timeout=5).stdout
    except (OSError, subprocess.SubprocessError):
        return ""
    for line in out.splitlines():
        if "image: " in line:
            return line.split("image: ", 1)[1].strip()
    return ""


def monitor_rule_key():
    """The nested mango's monitor rule key: shot.sh starts the INSTALLED mango,
    and 0.18 renamed monitorrule -> monitor_rule (the old name is an error)."""
    try:
        out = subprocess.run(["mango", "-v"], capture_output=True, text=True, timeout=5).stdout
    except (OSError, subprocess.SubprocessError):
        out = ""
    m = re.search(r"mango (\d+)\.(\d+)", out)
    return "monitor_rule" if m and (int(m[1]), int(m[2])) >= (0, 18) else "monitorrule"


def step_cmd(step):
    kind, _, arg = step.partition(":")
    if kind in ("hover", "click"):
        x, y = (int(v) for v in arg.split(","))
        # wlrctl moves relative: pin to the top-left corner, jump, then wiggle
        # (the jump alone does not deliver a motion event inside the target).
        cmd = (f"wlrctl pointer move -10000 -10000; sleep 0.2; wlrctl pointer move {x} {y}; "
               "sleep 0.2; wlrctl pointer move 2 0; sleep 0.1; wlrctl pointer move -2 0; sleep 1.2")
        if kind == "click":
            cmd += "; wlrctl pointer click left; sleep 1.2"
        return cmd
    if kind == "ipc":
        target, _, rest = arg.partition(".")
        fn, _, val = rest.partition(":")
        return f"qs ipc --pid $QSPID call {shlex.quote(target)} {shlex.quote(fn)} {shlex.quote(val) if val else ''}; sleep 1.5"
    if kind == "set":
        key, _, val = arg.partition("=")
        json.loads(val)   # fail early on a bad value
        py = ("import json,os\n"
              "p=os.path.expanduser('~/.config/archeotech/config.json'); d=json.load(open(p))\n"
              f"k={key!r}.split('.'); t=d\n"
              "for part in k[:-1]: t=t.setdefault(part,{})\n"
              f"t[k[-1]]=json.loads({val!r}); json.dump(d,open(p,'w'),indent=4)\n")
        return f"python3 -c {shlex.quote(py)}; sleep 2"
    if kind == "notify":
        return f"notify-send -t 0 Archeotech {shlex.quote(arg)}; sleep 2"
    if kind == "burst":
        # burst:<prefix>:<n>:<gap>:<shell cmd>: run the command, and at once start n
        # grims <gap> seconds apart (PPM, so each frame is taken before the last is
        # encoded): the frames of a fade that is over in 150 ms.
        prefix, n, gap, cmd = arg.split(":", 3)
        return (f"( {cmd} ) & for i in $(seq 1 {int(n)}); do grim -t ppm {shlex.quote(prefix)}-$(printf %02d $i).ppm & "
                f"sleep {float(gap)}; done; sleep 1.5")
    if kind == "sleep":
        return f"sleep {float(arg)}"
    sys.exit(f"desk-check: unknown step {step!r}")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--root", default=str(pathlib.Path(__file__).resolve().parents[1]))
    ap.add_argument("--size", default="1920x1200")
    ap.add_argument("--wallpaper", default="")
    ap.add_argument("--glass", default="glass")
    ap.add_argument("--blur", choices=["xray", "windows", "off"], default="xray")
    ap.add_argument("--app", choices=["dark", "light", "none"], default="dark")
    ap.add_argument("--zoom", action="append", default=[], help="X,Y,W,H region to upscale")
    ap.add_argument("--scale", type=int, default=6)
    ap.add_argument("--mango-line", action="append", default=[], help="extra mango config line")
    ap.add_argument("--theme", default="", help="theme variant (shot.sh --theme)")
    ap.add_argument("--set", action="append", default=[], help="config key=json, passed to shot.sh --set")
    ap.add_argument("--mango-libs", default="", help="dir of locally built libs (patched scenefx) for the nested mango")
    ap.add_argument("--keep", action="store_true")
    ap.add_argument("--out", required=True)
    ap.add_argument("steps", nargs="*")
    args = ap.parse_args()

    root = pathlib.Path(args.root).resolve()
    out = pathlib.Path(args.out).resolve()
    w, h = (int(v) for v in args.size.split("x"))
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="desk-check."))
    wall = args.wallpaper or live_wallpaper()
    extra = []
    if wall:
        shutil.copy(wall, tmp / ("wall" + pathlib.Path(wall).suffix))   # never hand shot.sh a live path
        extra += ["--wallpaper", str(tmp / ("wall" + pathlib.Path(wall).suffix))]

    script = []
    if args.app != "none":
        # Wide, bright, varied lines so a panel anywhere on screen has window text
        # behind it (what blur strength and edge checks need to show).
        fill = ("for i in $(seq 400); do printf '\\033[3%dm%s \\033[0m' $((i%6+1)) "
                "'archeotech -rwxr-xr-x root 14432 Sep 1 10:07 convertfilestopdf dbus-cleanup-sockets'; "
                "printf '\\033[1;37m%s\\033[0m\\n' ' ### WINDOW TEXT ### the quick brown fox jumps over the lazy dog'; done; sleep 120")
        script.append(APP[args.app] + f" sh -c {shlex.quote(fill)} >/dev/null 2>&1 & sleep 3")
    script += [step_cmd(s) for s in args.steps]

    mango = [f"{monitor_rule_key()}=name:HEADLESS-1,width:{w},height:{h},refresh:60,x:0,y:0,scale:1,rr:0",
             f"blur_layer={0 if args.blur == 'off' else 1}",
             f"blur_optimized={0 if args.blur == 'windows' else 1}"] + args.mango_line
    cmd = [str(root / "scripts" / "shot.sh"), "--root", str(root), "--renderer", "gles2",
           "--set", f"appearance.glass={json.dumps(args.glass)}",
           # the shell's own Behind windows setting follows --blur (panel alphas differ)
           "--set", f"appearance.glassBlur={json.dumps('windows' if args.blur == 'windows' else 'xray')}",
           "-w", "6"] + extra
    for line in mango:
        cmd += ["--mango-line", line]
    if script:
        cmd += ["--exec", "\n".join(script)]
    if args.theme:
        cmd += ["--theme", args.theme]
    for kv in args.set:
        cmd += ["--set", kv]
    if args.mango_libs:
        cmd += ["--mango-libs", args.mango_libs]
    if args.keep:
        cmd.append("--keep")
    res = subprocess.run(cmd + [str(out)], capture_output=True, text=True)
    sys.stdout.write("".join(l + "\n" for l in res.stdout.splitlines() if "run dir" in l or "shot:" in l))
    if res.returncode:
        sys.stderr.write(res.stderr[-2000:])
        sys.exit(res.returncode)

    if args.zoom:
        img = Image.open(out).convert("RGB")
        tiles = []
        for z in args.zoom:
            x, y, zw, zh = (int(v) for v in z.split(","))
            tiles.append(img.crop((x, y, x + zw, y + zh)).resize((zw * args.scale, zh * args.scale), Image.NEAREST))
        gap = 8
        sheet = Image.new("RGB", (sum(t.width for t in tiles) + gap * (len(tiles) - 1),
                                  max(t.height for t in tiles)), (255, 0, 255))
        x = 0
        for t in tiles:
            sheet.paste(t, (x, 0))
            x += t.width + gap
        zpath = out.with_name(out.stem + "-zoom.png")
        sheet.save(zpath)
        print(f"zoom: {zpath}")
    shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()
