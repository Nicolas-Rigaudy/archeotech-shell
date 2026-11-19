#!/bin/bash
# wallpaper-set.sh - Set wallpaper with optional logo overlay
#
# Usage:
#   wallpaper-set.sh <image>                Set wallpaper (respects active logo state)
#   wallpaper-set.sh <image> --screen NAME IMAGE ...
#                                           Same, with its own image on output NAME
#                                           (others, and unknown outputs, get <image>)
#   wallpaper-set.sh --toggle-logo <name>   Activate logo by name, or turn off if already active
#   wallpaper-set.sh --toggle-logo          Turn off active logo (legacy toggle for keybind)
#   wallpaper-set.sh --restore              Reapply last wallpaper (used at startup)
#   wallpaper-set.sh --status              Show current wallpaper and logo state
#   wallpaper-set.sh --print-color <image>  Print the accent extracted from <image>; applies nothing,
#                                           writes no state (shell picker preview)
#   wallpaper-set.sh --warm-all [DIR]       Pre-render all (wallpaper × logo) composites
#
# Logo names (defined in LOGOS array below):
#   arch     - Arch Linux crystal (adaptive color)
#   rebel    - Rebel Alliance symbol (adaptive color)
#   imperial - Imperial Aquila (adaptive color, PNG source)

set -e

# ── Paths ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
CACHE_DIR="$HOME/.cache/wallpaper"
COMPOSED_DIR="$CACHE_DIR/composed"          # per-(wallpaper,logo) keyed cache
LOGO_STATE="$CACHE_DIR/logo-active"         # active logo name, empty/absent = none
LAST_LOGO="$CACHE_DIR/logo-last"            # last active logo for keybind restore
LAST_WALL="$CACHE_DIR/last-wallpaper"
CURRENT_LINK="$CACHE_DIR/current"           # stable symlink → current wallpaper (hyprlock bg)
LAST_COLOR="$CACHE_DIR/last-color"
LAST_COLOR_FOR="$CACHE_DIR/last-color-for"
LAST_SCREENS="$CACHE_DIR/last-screens"      # "NAME<TAB>IMAGE" per output with its own image

# ── Cache key helper ─────────────────────────────────────────────────────────
# Composites are keyed by a 12-char sha1 of the wallpaper path (see
# output_image), which keeps the cache filenames short and stable.
_wall_hash() {
    printf "%s" "$1" | sha1sum | head -c 12
}

# ── Logo definitions ─────────────────────────────────────────────────────────
# Format: "name:path:type"   type = svg | png
declare -A LOGO_PATH LOGO_TYPE
LOGO_PATH[arch]="$SCRIPT_DIR/assets/arch-logo.svg"
LOGO_TYPE[arch]="svg"
LOGO_PATH[rebel]="$SCRIPT_DIR/assets/rebel-logo.svg"
LOGO_TYPE[rebel]="svg"
LOGO_PATH[imperial]="$SCRIPT_DIR/assets/imperial-logo.svg"
LOGO_TYPE[imperial]="svg"

# ── Appearance ────────────────────────────────────────────────────────────────
LOGO_SIZE_PERCENT=40    # % of the shorter wallpaper dimension
LOGO_OPACITY=60         # 0-100

# ── awww transition settings ─────────────────────────────────────────────────
TRANSITION="grow"
TRANSITION_POS="center"
TRANSITION_FPS=60
TRANSITION_DURATION=0.5

# ── Setup ────────────────────────────────────────────────────────────────────
mkdir -p "$CACHE_DIR" "$COMPOSED_DIR"

# ── Helper: get active logo name (empty string if none) ──────────────────────
active_logo() {
    if [ -f "$LOGO_STATE" ]; then
        cat "$LOGO_STATE"
    else
        echo ""
    fi
}

# ── Helper: extract accent color from image, with caching ────────────────────
# Pure extraction: prints the accent for <image>, touches no state. The cached
# wrapper below and `--print-color` (shell picker preview) both call it.
extract_wallpaper_color() {
    local img="$1"

    # Use the cached thumbnail when present (faster magick analysis on a
    # smaller image), otherwise fall back to the original wallpaper. The
    # previous `${thumb:-$img}` was wrong — bash's ${var:-} checks if the
    # variable is empty, not if the file exists, so it always picked thumb.
    local thumb="$HOME/.cache/wallpaper/thumbs/$(basename "$img").jpg"
    local src="$img"
    [ -f "$thumb" ] && src="$thumb"

    local avg_brightness
    avg_brightness=$(magick "$src" -resize 1x1! -format "%[fx:int(255*(r+g+b)/3)]" info: 2>/dev/null)
    avg_brightness="${avg_brightness:-128}"

    # Score each palette color: saturation (weighted 2x) + contrast vs wallpaper avg.
    # Two passes: first prefer saturated+contrasty, fall back to purely contrasty.
    # This ensures desaturated wallpapers (grey mountains, etc.) still get a visible color.
    local color
    color=$(magick "$src" \
        -resize 50x50! \
        +dither -colors 24 \
        -format "%c" histogram:info:- 2>/dev/null \
        | grep -oP '#[0-9A-Fa-f]{6}' \
        | awk -v avg="$avg_brightness" '
        {
            hex = $0
            r = strtonum("0x" substr(hex,2,2))
            g = strtonum("0x" substr(hex,4,2))
            b = strtonum("0x" substr(hex,6,2))
            bright = (r + g + b) / 3
            cmax = (r>g ? (r>b ? r : b) : (g>b ? g : b))
            cmin = (r<g ? (r<b ? r : b) : (g<b ? g : b))
            sat = cmax - cmin
            contrast = (bright > avg) ? bright - avg : avg - bright
            # Pass 1: saturated accent (sat>=20 to handle muted palettes)
            if (sat >= 20 && contrast >= 25)
                score1 = sat * 2 + contrast
            else
                score1 = 0
            if (score1 > best1_score) { best1_score = score1; best1 = hex }
            # Pass 2: pure contrast fallback (any color, just maximum contrast)
            if (contrast > best2_score) { best2_score = contrast; best2 = hex }
        }
        END { print (best1 != "" ? best1 : best2) }
        ')

    echo "$color"
}

get_wallpaper_color() {
    local img="$1"

    if [ -f "$LAST_COLOR" ] && [ -f "$LAST_COLOR_FOR" ]; then
        if [ "$(cat "$LAST_COLOR_FOR")" = "$img" ]; then
            cat "$LAST_COLOR"
            return
        fi
    fi

    local color
    color="$(extract_wallpaper_color "$img")"
    echo "$color" > "$LAST_COLOR"
    echo "$img" > "$LAST_COLOR_FOR"
    echo "$color"
}

# ── Helper: render logo PNG for a given logo name, color, and dimensions ─────
render_logo() {
    local logo_name="$1"
    local color="$2"
    local wall_w="$3"
    local wall_h="$4"
    local work="$5"     # private scratch dir: parallel runs never share files

    # Size relative to the shorter dimension so logos fit on portrait screens too
    local shorter=$(( wall_w < wall_h ? wall_w : wall_h ))
    local logo_px=$(( shorter * LOGO_SIZE_PERCENT / 100 ))
    local logo_type="${LOGO_TYPE[$logo_name]}"
    local logo_src="${LOGO_PATH[$logo_name]}"
    local logo_out="$work/logo-rendered.png"

    local opacity_decimal
    opacity_decimal=$(awk "BEGIN {printf \"%.2f\", $LOGO_OPACITY/100}")

    local logo_raw="$work/logo-raw.png"

    # Inner margin so sharp logo edges never sit at the canvas boundary.
    # The shadow blur can then spread freely without clipping.
    local inner_margin=16
    local render_px=$(( logo_px - inner_margin * 2 ))

    if [ "$logo_type" = "svg" ]; then
        # Inject color/opacity placeholders and rasterize
        sed \
            -e "s/LOGO_COLOR/$color/g" \
            -e "s/LOGO_OPACITY/$opacity_decimal/g" \
            "$logo_src" > "$work/logo-colored.svg"

        # Normalize by area: target sqrt(w*h) = render_px for all logos.
        # This gives equal visual weight regardless of aspect ratio — a wide flat
        # logo and a tall square logo appear as the same "sticker size".
        local raw_render="$work/logo-raw-render.png"
        local norm_w norm_h
        read -r norm_w norm_h < <(python3 -c "
import xml.etree.ElementTree as ET, re, math, sys
t = ET.parse(sys.argv[1])
vb = t.getroot().get('viewBox', '')
parts = re.split(r'[\s,]+', vb.strip())
vw = float(parts[2]) if len(parts) >= 4 else 1.0
vh = float(parts[3]) if len(parts) >= 4 else 1.0
ratio = vw / vh
target = $render_px
# sqrt(w*h)=target, w/h=ratio → w=target*sqrt(ratio), h=target/sqrt(ratio)
w = target * math.sqrt(ratio)
h = target / math.sqrt(ratio)
print(round(w), round(h))
" "$work/logo-colored.svg" 2>/dev/null || echo "$render_px $render_px")
        rsvg-convert \
            -w "${norm_w}" -h "${norm_h}" \
            "$work/logo-colored.svg" \
            -o "$raw_render"
        # Pad with inner_margin on all sides
        local actual_w actual_h canvas_w canvas_h
        actual_w=$(magick "$raw_render" -format "%w" info:)
        actual_h=$(magick "$raw_render" -format "%h" info:)
        canvas_w=$(( actual_w + inner_margin * 2 ))
        canvas_h=$(( actual_h + inner_margin * 2 ))
        magick "$raw_render" \
            -gravity Center \
            -background none \
            -extent "${canvas_w}x${canvas_h}" \
            "$logo_raw"

    elif [ "$logo_type" = "png" ]; then
        # Colorize greyscale PNG: tint with extracted color, apply opacity
        local r g b
        r=$(printf "%d" "0x${color:1:2}")
        g=$(printf "%d" "0x${color:3:2}")
        b=$(printf "%d" "0x${color:5:2}")

        magick "$logo_src" \
            -resize "${render_px}x${render_px}" \
            -alpha set \
            \( +clone -alpha extract \) \
            -channel RGB \
            -level 0%,100% \
            +channel \
            -fill "$color" \
            -colorize 100 \
            \( -clone 0 -alpha extract \) \
            -compose CopyOpacity -composite \
            -channel Alpha -evaluate multiply "$opacity_decimal" +channel \
            -gravity Center -background none -extent "${logo_px}x${logo_px}" \
            "$logo_raw"
    fi

    # Soft centred shadow/halo: blur the logo's alpha shape outward, fill black,
    # place centred behind the logo. No offset — pure even glow under the shape.
    # logo_raw already has inner_margin padding baked in — shadow blurs into that space
    local shadow_blur=12
    local raw_w raw_h
    raw_w=$(magick "$logo_raw" -format "%w" info:)
    raw_h=$(magick "$logo_raw" -format "%h" info:)
    magick "$logo_raw" \
        -channel Alpha -blur "0x${shadow_blur}" +channel \
        -fill black -colorize 100 \
        -channel Alpha -evaluate multiply 0.95 +channel \
        "$work/logo-shadow-layer.png"
    magick -size "${raw_w}x${raw_h}" xc:none \
        "$work/logo-shadow-layer.png" -gravity Center -composite \
        "$logo_raw" -gravity Center -composite \
        "$logo_out"

    echo "$logo_out"
}

# ── Fit settings (item_148) ──────────────────────────────────────────────────
# How an image is laid onto a screen whose orientation differs from it (a
# landscape image on a portrait screen, or the reverse). Same-orientation
# screens are always cover-cropped from the centre, as before.
#   fill   cover crop; ANCHOR picks the kept part: left|centre|right (for a tall
#          image on a wide screen: left = top, right = bottom)
#   blur   whole image, centred over a blurred, darkened cover of itself
#   edges  whole image; the bars repeat its outermost rows/columns, softened
# Read from config.json `wallpaper.fit` / `wallpaper.anchor` (Settings >
# Appearance > Wallpaper), per output from `wallpaper.screens.<NAME>.fit` /
# `.anchor` (a missing field inherits the all-screens value). WALLPAPER_CONFIG
# (JSON of that `wallpaper` object; the shell passes it so a just-changed
# setting applies before config.json is written) replaces the file;
# WALLPAPER_FIT / WALLPAPER_ANCHOR override the all-screens values for tests.
SHELL_CONFIG="$HOME/.config/archeotech/config.json"
FIT=""
ANCHOR=""
declare -A SCREEN_FIT SCREEN_ANCHOR
load_fit_settings() {
    [ -n "$FIT" ] && return 0
    local cfg="" name f a
    cfg=$(python3 - "$SHELL_CONFIG" 2>/dev/null <<'PY'
import json, os, sys
w = None
if os.environ.get("WALLPAPER_CONFIG"):
    try:
        w = json.loads(os.environ["WALLPAPER_CONFIG"])
    except Exception:
        w = None
if w is None:
    try:
        d = json.load(open(sys.argv[1]))
    except Exception:
        d = {}
    w = d.get("wallpaper") if isinstance(d, dict) else None
w = w if isinstance(w, dict) else {}
def word(v):
    return v if isinstance(v, str) and v.isalpha() else "-"
print("*", word(w.get("fit")), word(w.get("anchor")))
screens = w.get("screens")
for name, s in (screens.items() if isinstance(screens, dict) else []):
    if isinstance(s, dict) and name and name != "*" and not any(c.isspace() for c in name):
        print(name, word(s.get("fit")), word(s.get("anchor")))
PY
) || cfg=""
    FIT="" ANCHOR=""
    while read -r name f a; do
        [ -n "$name" ] || continue
        [ "$f" = - ] && f=""
        [ "$a" = - ] && a=""
        if [ "$name" = "*" ]; then FIT="$f"; ANCHOR="$a"
        else SCREEN_FIT[$name]="$f"; SCREEN_ANCHOR[$name]="$a"; fi
    done <<<"$cfg"
    FIT="${WALLPAPER_FIT:-${FIT:-fill}}"
    ANCHOR="${WALLPAPER_ANCHOR:-${ANCHOR:-centre}}"
    case "$FIT" in fill|blur|edges) ;; *) FIT=fill ;; esac
    case "$ANCHOR" in left|centre|right) ;; *) ANCHOR=centre ;; esac
}

# fit_for NAME / anchor_for NAME: the output's own value, else the all-screens one.
fit_for() {
    local f="${SCREEN_FIT[$1]:-}"
    case "$f" in fill|blur|edges) echo "$f" ;; *) echo "$FIT" ;; esac
}
anchor_for() {
    local a="${SCREEN_ANCHOR[$1]:-}"
    case "$a" in left|centre|right) echo "$a" ;; *) echo "$ANCHOR" ;; esac
}

# ── Per-output images ────────────────────────────────────────────────────────
# MAIN_WALL goes to every output without its own entry in SCREEN_IMG.
MAIN_WALL=""
declare -A SCREEN_IMG
image_for() {
    local img="${SCREEN_IMG[$1]:-}"
    if [ -n "$img" ] && [ -f "$img" ]; then echo "$img"; else echo "$MAIN_WALL"; fi
}
load_last_screens() {
    local name img
    [ -f "$LAST_SCREENS" ] || return 0
    while IFS=$'\t' read -r name img; do
        [ -n "$name" ] && [ -n "$img" ] && SCREEN_IMG[$name]="$img"
    done <"$LAST_SCREENS"
    return 0
}
save_last_screens() {
    local name tmp
    if [ ${#SCREEN_IMG[@]} -eq 0 ]; then rm -f "$LAST_SCREENS"; return 0; fi
    tmp=$(mktemp "$CACHE_DIR/.screens.XXXXXX")
    for name in "${!SCREEN_IMG[@]}"; do
        printf '%s\t%s\n' "$name" "${SCREEN_IMG[$name]}"
    done | sort >"$tmp"
    mv -f "$tmp" "$LAST_SCREENS"
}

# ── Helper: image size "W H" ─────────────────────────────────────────────────
_image_size() {
    magick identify -format "%w %h" "$1[0]" 2>/dev/null
}

# ── Helper: lay <wallpaper> onto a WxH canvas: fit_image wall W H out fit anchor
fit_image() {
    local wallpaper="$1" w="$2" h="$3" out="$4" fit="$5" anchor="$6"
    local iw ih
    read -r iw ih < <(_image_size "$wallpaper")

    case "$fit" in
        blur)
            magick \
                \( "$wallpaper" -resize "${w}x${h}^" -gravity Center -extent "${w}x${h}" \
                   -blur 0x20 -fill black -colorize 40 \) \
                \( "$wallpaper" -resize "${w}x${h}" \) \
                -gravity Center -composite +repage "$out"
            ;;
        edges)
            _fit_edges "$wallpaper" "$w" "$h" "$out"
            ;;
        *)
            # Cover crop. The anchor slides along the axis that gets cropped:
            # horizontal when the image is wider than the screen, else vertical.
            local gravity=Center
            if [ "$anchor" != centre ]; then
                if [ $(( iw * h )) -gt $(( w * ih )) ]; then
                    [ "$anchor" = left ] && gravity=West || gravity=East
                else
                    [ "$anchor" = left ] && gravity=North || gravity=South
                fi
            fi
            magick "$wallpaper" -resize "${w}x${h}^" -gravity "$gravity" \
                -extent "${w}x${h}" +repage "$out"
            ;;
    esac
}

# Fit inside, then fill each bar by stretching the image's outermost 4 px
# rows (or columns) across it and blurring, so the bars carry its edge colours.
_fit_edges() {
    local wallpaper="$1" w="$2" h="$3" out="$4"
    local tmpd fw fh
    tmpd=$(mktemp -d "$(dirname "$out")/edges.XXXXXX") || return 1
    magick "$wallpaper" -resize "${w}x${h}" +repage "$tmpd/fit.png"
    read -r fw fh < <(_image_size "$tmpd/fit.png")
    local a=0 b=0
    if [ "$fh" -lt "$h" ]; then
        a=$(( (h - fh) / 2 )); b=$(( h - fh - a ))
    elif [ "$fw" -lt "$w" ]; then
        a=$(( (w - fw) / 2 )); b=$(( w - fw - a ))
    fi
    if [ "$a" -lt 1 ] || [ "$b" -lt 1 ]; then
        # No real bars (rounding): plain cover crop.
        magick "$wallpaper" -resize "${w}x${h}^" -gravity Center -extent "${w}x${h}" +repage "$out"
    elif [ "$fh" -lt "$h" ]; then
        magick "$tmpd/fit.png" -gravity North -crop "${fw}x4+0+0" +repage \
            -resize "${fw}x${a}!" -blur 0x6 "$tmpd/a.png"
        magick "$tmpd/fit.png" -gravity South -crop "${fw}x4+0+0" +repage \
            -resize "${fw}x${b}!" -blur 0x6 "$tmpd/b.png"
        magick "$tmpd/a.png" "$tmpd/fit.png" "$tmpd/b.png" -append \
            -gravity Center -extent "${w}x${h}" +repage "$out"
    else
        magick "$tmpd/fit.png" -gravity West -crop "4x${fh}+0+0" +repage \
            -resize "${a}x${fh}!" -blur 0x6 "$tmpd/a.png"
        magick "$tmpd/fit.png" -gravity East -crop "4x${fh}+0+0" +repage \
            -resize "${b}x${fh}!" -blur 0x6 "$tmpd/b.png"
        magick "$tmpd/a.png" "$tmpd/fit.png" "$tmpd/b.png" +append \
            -gravity Center -extent "${w}x${h}" +repage "$out"
    fi
    rm -rf "$tmpd"
}

# ── Helper: list outputs as "name W H" (empty without awww) ──────────────────
list_outputs() {
    command -v awww >/dev/null 2>&1 || return 0
    local line name res
    while IFS= read -r line; do
        name=$(grep -oP '^: \K\S+(?=:)' <<<"$line" || true)
        res=$(grep -oP '\d+x\d+' <<<"$line" | head -1 || true)
        [ -n "$name" ] && [ -n "$res" ] && echo "$name ${res%x*} ${res#*x}"
    done < <(awww query 2>/dev/null)
    return 0
}

# ── Helper: the image to send to one WxH output (per-combo cached) ───────────
# output_image <wallpaper> <logo> W H <fit> <anchor>. Keyed by wallpaper, logo
# (or "plain"), fit, anchor and output size, so every screen gets a composite
# built at its own size. Prints the path. A plain centre crop needs no file:
# awww's own default resize crops from the centre.
output_image() {
    local wallpaper="$1" logo="$2" w="$3" h="$4" fit="$5" anchor="$6"
    # The fit only applies across orientations; anchor only to fill.
    local iw ih
    read -r iw ih < <(_image_size "$wallpaper")
    if [ $(( ih > iw )) = $(( h > w )) ]; then fit=fill; anchor=centre; fi
    [ "$fit" = fill ] || anchor=centre
    if [ -z "$logo" ] && [ "$fit" = fill ] && [ "$anchor" = centre ]; then
        echo "$wallpaper"
        return 0
    fi
    local out
    out="$COMPOSED_DIR/$(_wall_hash "$wallpaper")-${logo:-plain}-${fit}-${anchor}-${w}x${h}.png"
    if [ ! -f "$out" ]; then
        # Build in a private dir, publish with one mv: a background warm and a
        # foreground apply can build the same key at once without mixing files,
        # and a failed step never leaves a wrong image under a valid key.
        local work ok=0
        work=$(mktemp -d "$COMPOSED_DIR/.work.XXXXXX") || return 1
        if _build_output "$wallpaper" "$logo" "$w" "$h" "$fit" "$anchor" "$work" \
            && [ -s "$work/out.png" ]; then
            mv -f "$work/out.png" "$out" && ok=1
        fi
        rm -rf "$work"
        if [ "$ok" != 1 ]; then
            echo "wallpaper-set: could not build $(basename "$out")" >&2
            return 1
        fi
    fi
    echo "$out"
}

# Steps of one build, all inside <work>; each failure returns 1 (callers run
# this in a condition, where set -e is off).
_build_output() {
    local wallpaper="$1" logo="$2" w="$3" h="$4" fit="$5" anchor="$6" work="$7"
    fit_image "$wallpaper" "$w" "$h" "$work/out.png" "$fit" "$anchor" || return 1
    [ -n "$logo" ] || return 0
    local color logo_png
    # Only the main wallpaper's colour is cached (it is the one read as the accent).
    if [ "$wallpaper" = "$MAIN_WALL" ] || [ -z "$MAIN_WALL" ]; then
        color=$(get_wallpaper_color "$wallpaper") || return 1
    else
        color=$(extract_wallpaper_color "$wallpaper") || return 1
    fi
    logo_png=$(render_logo "$logo" "$color" "$w" "$h" "$work") || return 1
    [ -s "$logo_png" ] || return 1
    magick "$work/out.png" "$logo_png" -gravity Center -composite "$work/out.png"
}

# ── Helper: pre-build the composites for every current output ────────────────
# composite_logo <wallpaper> <logo>: <wallpaper> is the main image; outputs
# with their own image (SCREEN_IMG) build theirs.
composite_logo() {
    local wallpaper="$1" logo_name="$2"
    local MAIN_WALL="$wallpaper"
    local outputs name w h rc=0
    load_fit_settings   # here, not in output_image's subshells: read config once
    outputs=$(list_outputs)
    [ -n "$outputs" ] || outputs="default 1920 1080"
    while read -r name w h; do
        output_image "$(image_for "$name")" "$logo_name" "$w" "$h" \
            "$(fit_for "$name")" "$(anchor_for "$name")" >/dev/null || rc=1
    done <<<"$outputs"
    return "$rc"
}

# ── Background warm: precompute composites for current wallpaper × other ─────
# logos (and the plain fit when a logo is on). After applying any wallpaper,
# kicks off a detached subshell so the next logo switch is a cache hit.
warm_other_logos() {
    local wallpaper="$1"
    local skip_logo="${2:-}"
    (
        for lg in "${!LOGO_PATH[@]}"; do
            [ "$lg" = "$skip_logo" ] && continue
            composite_logo "$wallpaper" "$lg" 2>/dev/null
        done
        [ -n "$skip_logo" ] && composite_logo "$wallpaper" "" 2>/dev/null
    ) >/dev/null 2>&1 &
    disown 2>/dev/null || true
}

# ── Helper: apply wallpaper via awww ─────────────────────────────────────────
# apply_wallpaper <wallpaper> [logo]: sends each output the image built for its
# own size with its fit (and the logo composited on top); outputs listed in
# SCREEN_IMG get their own image.
apply_wallpaper() {
    local wallpaper="$1" logo="${2:-}"
    MAIN_WALL="$wallpaper"

    local swww_opts=(
        --transition-type "$TRANSITION"
        --transition-pos "$TRANSITION_POS"
        --transition-fps "$TRANSITION_FPS"
        --transition-duration "$TRANSITION_DURATION"
    )

    local outputs name w h img
    load_fit_settings   # once, before output_image's subshells
    outputs=$(list_outputs)
    if [ -z "$outputs" ]; then
        img=$(output_image "$wallpaper" "$logo" 1920 1080 "$FIT" "$ANCHOR") || img="$wallpaper"
        awww img "$img" "${swww_opts[@]}"
        return
    fi
    # One screen's failed build falls back to the raw image; the rest go on.
    local own
    while read -r name w h; do
        own=$(image_for "$name")
        img=$(output_image "$own" "$logo" "$w" "$h" "$(fit_for "$name")" "$(anchor_for "$name")") \
            || img="$own"
        awww img "$img" --outputs "$name" "${swww_opts[@]}" \
            || echo "wallpaper-set: awww failed on $name" >&2
    done <<<"$outputs"
}

# ── Main logic ────────────────────────────────────────────────────────────────

case "${1:-}" in

    --toggle-logo)
        # Arg 2: logo name. No arg = toggle last active (on if off, off if on).
        REQUESTED="${2:-}"

        if [ ! -f "$LAST_WALL" ]; then
            echo "No wallpaper set yet." >&2
            exit 1
        fi
        ORIGINAL="$(cat "$LAST_WALL")"
        if [ ! -f "$ORIGINAL" ]; then
            echo "Wallpaper file not found: $ORIGINAL" >&2
            exit 1
        fi

        CURRENT="$(active_logo)"
        load_last_screens

        if [ -n "$REQUESTED" ] && [ "${LOGO_PATH[$REQUESTED]+set}" != "set" ]; then
            echo "Unknown logo: $REQUESTED" >&2
            echo "Available: ${!LOGO_PATH[*]}" >&2
            exit 1
        fi

        # No arg: if a logo is on → turn off; if off → restore last used logo
        if [ -z "$REQUESTED" ]; then
            if [ -n "$CURRENT" ]; then
                REQUESTED=""  # fall through to turn-off branch below
            elif [ -f "$LAST_LOGO" ]; then
                REQUESTED="$(cat "$LAST_LOGO")"
            fi
        fi

        if [ -z "$REQUESTED" ] || [ "$CURRENT" = "$REQUESTED" ]; then
            # Turn off
            rm -f "$LOGO_STATE"
            echo "Logo: OFF" >&2
            apply_wallpaper "$ORIGINAL"
            warm_other_logos "$ORIGINAL"
        else
            # Activate logo, remember it as last used
            echo "$REQUESTED" > "$LOGO_STATE"
            echo "$REQUESTED" > "$LAST_LOGO"
            echo "Logo: $REQUESTED ON" >&2
            apply_wallpaper "$ORIGINAL" "$REQUESTED"
            warm_other_logos "$ORIGINAL" "$REQUESTED"
        fi
        ;;

    --restore)
        if [ -f "$LAST_WALL" ]; then
            load_last_screens
            ARGS=("$(cat "$LAST_WALL")")
            for name in "${!SCREEN_IMG[@]}"; do ARGS+=(--screen "$name" "${SCREEN_IMG[$name]}"); done
            exec "$0" "${ARGS[@]}"
        else
            echo "No previous wallpaper saved." >&2
            exit 1
        fi
        ;;

    --warm-all)
        # Pre-render every (wallpaper, logo) composite into the keyed cache.
        # Doesn't apply anything — purely fills the cache so future picks are
        # cache-hits. Optional 2nd arg: wallpaper directory to scan.
        WALL_DIR="${2:-$HOME/.config/archeotech/wallpapers}"
        if [ ! -d "$WALL_DIR" ]; then
            echo "Directory not found: $WALL_DIR" >&2
            exit 1
        fi
        # Collect wallpapers
        mapfile -t WALLS < <(find "$WALL_DIR" -maxdepth 1 -type f \
            -regextype posix-extended -iregex '.*\.(jpe?g|png|webp)$' | sort)
        TOTAL=$(( ${#WALLS[@]} * ${#LOGO_PATH[@]} ))
        I=0
        for wall in "${WALLS[@]}"; do
            for lg in "${!LOGO_PATH[@]}"; do
                I=$(( I + 1 ))
                printf '[%2d/%2d] %s × %s … ' "$I" "$TOTAL" "$(basename "$wall")" "$lg"
                if composite_logo "$wall" "$lg" 2>/dev/null; then
                    echo "done"
                else
                    echo "FAILED"
                fi
            done
        done
        echo "Cache: $(du -sh "$COMPOSED_DIR" 2>/dev/null | cut -f1)"
        ;;

    --print-color)
        [ -f "${2:-}" ] || { echo "usage: wallpaper-set.sh --print-color <image>" >&2; exit 2; }
        # The applied wallpaper's cached colour, else extract without caching.
        if [ -f "$LAST_COLOR" ] && [ -f "$LAST_COLOR_FOR" ] && [ "$(cat "$LAST_COLOR_FOR")" = "$2" ]; then
            cat "$LAST_COLOR"
        else
            extract_wallpaper_color "$2"
        fi
        ;;
    --status)
        CURRENT="$(active_logo)"
        if [ -n "$CURRENT" ]; then
            echo "logo=$CURRENT"
        else
            echo "logo=off"
        fi
        [ -f "$LAST_WALL" ] && echo "wallpaper=$(cat "$LAST_WALL")"
        ;;

    "")
        echo "Usage: wallpaper-set.sh <image> [--screen NAME IMAGE]..."
        echo "       wallpaper-set.sh --toggle-logo [arch|rebel|imperial]"
        echo "       wallpaper-set.sh --restore"
        echo "       wallpaper-set.sh --status"
        exit 1
        ;;

    *)
        WALLPAPER="$1"
        shift

        if [ ! -f "$WALLPAPER" ]; then
            echo "Error: file not found: $WALLPAPER" >&2
            exit 1
        fi
        while [ $# -gt 0 ]; do
            if [ "$1" != --screen ] || [ $# -lt 3 ]; then
                echo "Usage: wallpaper-set.sh <image> [--screen NAME IMAGE]..." >&2
                exit 2
            fi
            # Output names are plain words (mango prints e.g. DP-3, HDMI-A-1).
            if ! [[ "$2" =~ ^[A-Za-z0-9._:-]+$ ]]; then
                echo "wallpaper-set: bad output name: $2" >&2
                exit 2
            fi
            # A missing per-screen file is skipped (that output gets <image>), and
            # the run then exits 3 so the shell does not retry the same plan.
            if [ -f "$3" ]; then SCREEN_IMG[$2]="$3"
            else echo "wallpaper-set: $2: file not found: $3" >&2; SKIPPED=1; fi
            shift 3
        done

        echo "$WALLPAPER" > "$LAST_WALL"
        save_last_screens
        # Repoint the stable symlink hyprlock's background reads (raw wallpaper,
        # no logo overlay — matches the prior swaylock --image behaviour).
        ln -sfn "$WALLPAPER" "$CURRENT_LINK"

        CURRENT="$(active_logo)"
        apply_wallpaper "$WALLPAPER" "$CURRENT"
        # Warm other logos in the background so the next logo switch is instant
        warm_other_logos "$WALLPAPER" "$CURRENT"
        if [ "${SKIPPED:-0}" = 1 ]; then exit 3; fi
        ;;
esac
