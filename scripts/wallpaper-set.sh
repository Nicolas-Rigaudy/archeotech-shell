#!/bin/bash
# wallpaper-set.sh - Set wallpaper with optional logo overlay
#
# Usage:
#   wallpaper-set.sh <image>                Set wallpaper (respects active logo state)
#   wallpaper-set.sh --toggle-logo <name>   Activate logo by name, or turn off if already active
#   wallpaper-set.sh --toggle-logo          Turn off active logo (legacy toggle for keybind)
#   wallpaper-set.sh --restore              Reapply last wallpaper (used at startup)
#   wallpaper-set.sh --status              Show current wallpaper and logo state
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
PLAIN_PORTRAIT_IMG="$CACHE_DIR/plain-portrait.png"
LOGO_STATE="$CACHE_DIR/logo-active"         # active logo name, empty/absent = none
LAST_LOGO="$CACHE_DIR/logo-last"            # last active logo for keybind restore
LAST_WALL="$CACHE_DIR/last-wallpaper"
CURRENT_LINK="$CACHE_DIR/current"           # stable symlink → current wallpaper (hyprlock bg)
LAST_COLOR="$CACHE_DIR/last-color"
LAST_COLOR_FOR="$CACHE_DIR/last-color-for"

# Backwards-compat: old code wrote these. Used as fallback names by --status etc.
COMPOSED_IMG="$CACHE_DIR/composed.png"
COMPOSED_PORTRAIT_IMG="$CACHE_DIR/composed-portrait.png"

# ── Cache key helpers ────────────────────────────────────────────────────────
# Compose path per (wallpaper, logo, orientation). The hash keeps filenames
# short and stable; sha1 is fast and good enough for cache identity.
_wall_hash() {
    printf "%s" "$1" | sha1sum | head -c 12
}
composed_path() {
    local wallpaper="$1" logo="$2" orientation="${3:-l}"
    echo "$COMPOSED_DIR/$(_wall_hash "$wallpaper")-${logo}-${orientation}.png"
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
get_wallpaper_color() {
    local img="$1"

    if [ -f "$LAST_COLOR" ] && [ -f "$LAST_COLOR_FOR" ]; then
        if [ "$(cat "$LAST_COLOR_FOR")" = "$img" ]; then
            cat "$LAST_COLOR"
            return
        fi
    fi

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

    # Size relative to the shorter dimension so logos fit on portrait screens too
    local shorter=$(( wall_w < wall_h ? wall_w : wall_h ))
    local logo_px=$(( shorter * LOGO_SIZE_PERCENT / 100 ))
    local logo_type="${LOGO_TYPE[$logo_name]}"
    local logo_src="${LOGO_PATH[$logo_name]}"
    local logo_out="$CACHE_DIR/logo-rendered.png"

    local opacity_decimal
    opacity_decimal=$(awk "BEGIN {printf \"%.2f\", $LOGO_OPACITY/100}")

    local logo_raw="$CACHE_DIR/logo-raw.png"

    # Inner margin so sharp logo edges never sit at the canvas boundary.
    # The shadow blur can then spread freely without clipping.
    local inner_margin=16
    local render_px=$(( logo_px - inner_margin * 2 ))

    if [ "$logo_type" = "svg" ]; then
        # Inject color/opacity placeholders and rasterize
        sed \
            -e "s/LOGO_COLOR/$color/g" \
            -e "s/LOGO_OPACITY/$opacity_decimal/g" \
            "$logo_src" > "$CACHE_DIR/logo-colored.svg"

        # Normalize by area: target sqrt(w*h) = render_px for all logos.
        # This gives equal visual weight regardless of aspect ratio — a wide flat
        # logo and a tall square logo appear as the same "sticker size".
        local raw_render="$CACHE_DIR/logo-raw-render.png"
        local norm_w norm_h
        read -r norm_w norm_h < <(python3 -c "
import xml.etree.ElementTree as ET, re, math
t = ET.parse('$CACHE_DIR/logo-colored.svg')
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
" 2>/dev/null || echo "$render_px $render_px")
        rsvg-convert \
            -w "${norm_w}" -h "${norm_h}" \
            "$CACHE_DIR/logo-colored.svg" \
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
        /tmp/logo-shadow-layer.png
    magick -size "${raw_w}x${raw_h}" xc:none \
        /tmp/logo-shadow-layer.png -gravity Center -composite \
        "$logo_raw" -gravity Center -composite \
        "$logo_out"

    echo "$logo_out"
}

# ── Helper: composite logo onto wallpaper at given dimensions ────────────────
# For landscape wallpapers on portrait canvases (and vice versa), we use a
# "blurred backdrop" approach: the image is blurred/darkened to fill the canvas,
# then the sharp image (fitted to contain) is composited centered on top.
# This avoids heavy zoom/crop while filling the full screen.
_compose_at_size() {
    local wallpaper="$1"
    local logo_name="$2"
    local color="$3"
    local out_w="$4"
    local out_h="$5"
    local out_file="$6"

    local logo_png
    logo_png=$(render_logo "$logo_name" "$color" "$out_w" "$out_h")

    # Detect if wallpaper and output have mismatched orientation (landscape vs portrait)
    local wall_w wall_h
    wall_w=$(magick "$wallpaper" -format "%w" info: 2>/dev/null)
    wall_h=$(magick "$wallpaper" -format "%h" info: 2>/dev/null)
    local wall_is_portrait=$(( wall_h > wall_w ? 1 : 0 ))
    local out_is_portrait=$(( out_h > out_w ? 1 : 0 ))

    if [ "$wall_is_portrait" != "$out_is_portrait" ]; then
        # Orientation mismatch: blurred backdrop + sharp centered image
        magick \
            \( "$wallpaper" -resize "${out_w}x${out_h}^" -gravity Center -extent "${out_w}x${out_h}" \
               -blur 0x20 -fill black -colorize 40 \) \
            \( "$wallpaper" -resize "${out_w}x${out_h}" \) \
            -gravity Center -composite \
            \( "$logo_png" \) \
            -gravity Center -composite \
            "$out_file"
    else
        # Same orientation: simple cover crop (original behaviour)
        magick \
            \( "$wallpaper" -resize "${out_w}x${out_h}^" -gravity Center -extent "${out_w}x${out_h}" \) \
            \( "$logo_png" \) \
            -gravity Center -composite \
            "$out_file"
    fi
}

# ── Helper: composite logo onto wallpaper (per-combo cached) ─────────────────
# Writes to keyed cache files so every (wallpaper, logo) pair is preserved.
# Switching logos on a previously-seen wallpaper hits the cache instantly.
# Also creates a portrait variant if a portrait output is detected.
composite_logo() {
    local wallpaper="$1"
    local logo_name="$2"

    local land_out portrait_out
    land_out=$(composed_path "$wallpaper" "$logo_name" l)
    portrait_out=$(composed_path "$wallpaper" "$logo_name" p)

    # Detect portrait output once — needed both for cache validity and for the
    # build step below.
    local pw="" ph="" portrait_res=""
    if command -v awww >/dev/null 2>&1; then
        portrait_res=$(awww query 2>/dev/null \
            | grep -oP '\d+x\d+' \
            | awk -F'x' '$2 > $1 {print; exit}')
        if [ -n "$portrait_res" ]; then
            pw=$(echo "$portrait_res" | cut -dx -f1)
            ph=$(echo "$portrait_res" | cut -dx -f2)
        fi
    fi

    # Cache hit when landscape exists AND (no portrait output OR portrait cached too)
    if [ -f "$land_out" ] && { [ -z "$portrait_res" ] || [ -f "$portrait_out" ]; }; then
        return
    fi

    local color
    color=$(get_wallpaper_color "$wallpaper")

    # Build landscape composite (1920x1080 — used by all landscape outputs)
    if [ ! -f "$land_out" ]; then
        _compose_at_size "$wallpaper" "$logo_name" "$color" 1920 1080 "$land_out"
    fi

    # Build portrait composite for any portrait output detected
    if [ -n "$portrait_res" ] && [ ! -f "$portrait_out" ]; then
        _compose_at_size "$wallpaper" "$logo_name" "$color" "$pw" "$ph" "$portrait_out"
    fi
}

# ── Background warm: precompute composites for current wallpaper × other ─────
# logos. After applying any wallpaper, kicks off a detached subshell that
# generates the missing combos so the next logo switch is cache-hit.
warm_other_logos() {
    local wallpaper="$1"
    local skip_logo="${2:-}"
    (
        for lg in "${!LOGO_PATH[@]}"; do
            [ "$lg" = "$skip_logo" ] && continue
            composite_logo "$wallpaper" "$lg" 2>/dev/null
        done
    ) >/dev/null 2>&1 &
    disown 2>/dev/null || true
}

# ── Helper: build a portrait-adapted plain wallpaper (no logo) ───────────────
# If a landscape wallpaper is being sent to a portrait output, generate a
# blurred-backdrop version so it doesn't look zoomed in.
_prepare_plain_portrait() {
    local wallpaper="$1"
    local pw="$2"
    local ph="$3"

    local wall_w wall_h
    wall_w=$(magick "$wallpaper" -format "%w" info: 2>/dev/null)
    wall_h=$(magick "$wallpaper" -format "%h" info: 2>/dev/null)
    local wall_is_portrait=$(( wall_h > wall_w ? 1 : 0 ))
    local out_is_portrait=$(( ph > pw ? 1 : 0 ))

    if [ "$wall_is_portrait" != "$out_is_portrait" ]; then
        magick \
            \( "$wallpaper" -resize "${pw}x${ph}^" -gravity Center -extent "${pw}x${ph}" \
               -blur 0x20 -fill black -colorize 40 \) \
            \( "$wallpaper" -resize "${pw}x${ph}" \) \
            -gravity Center -composite \
            "$PLAIN_PORTRAIT_IMG"
    else
        # Already matching orientation — cover crop is fine
        magick "$wallpaper" -resize "${pw}x${ph}^" -gravity Center -extent "${pw}x${ph}" \
            "$PLAIN_PORTRAIT_IMG"
    fi
}

# ── Helper: apply wallpaper via awww ─────────────────────────────────────────
# apply_wallpaper <landscape_img> [portrait_img]
# If portrait_img is given, routes it to portrait outputs; landscape_img to the rest.
# If portrait_img is omitted, builds a plain portrait variant on the fly if needed.
apply_wallpaper() {
    local img="$1"
    local portrait_img="${2:-}"

    local swww_opts=(
        --transition-type "$TRANSITION"
        --transition-pos "$TRANSITION_POS"
        --transition-fps "$TRANSITION_FPS"
        --transition-duration "$TRANSITION_DURATION"
    )

    if command -v awww >/dev/null 2>&1; then
        # Route per output, building a portrait variant on the fly if needed
        while IFS= read -r line; do
            local output res pw ph
            output=$(echo "$line" | grep -oP '^: \K\S+(?=:)')
            res=$(echo "$line" | grep -oP '\d+x\d+' | head -1)
            pw=$(echo "$res" | cut -dx -f1)
            ph=$(echo "$res" | cut -dx -f2)
            if [ -n "$ph" ] && [ "$ph" -gt "$pw" ] 2>/dev/null; then
                if [ -n "$portrait_img" ]; then
                    awww img "$portrait_img" --outputs "$output" "${swww_opts[@]}"
                else
                    _prepare_plain_portrait "$img" "$pw" "$ph"
                    awww img "$PLAIN_PORTRAIT_IMG" --outputs "$output" "${swww_opts[@]}"
                fi
            else
                awww img "$img" --outputs "$output" "${swww_opts[@]}"
            fi
        done < <(awww query 2>/dev/null)
    else
        awww img "$img" "${swww_opts[@]}"
    fi
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
            composite_logo "$ORIGINAL" "$REQUESTED"
            land_img=$(composed_path "$ORIGINAL" "$REQUESTED" l)
            portrait_img=$(composed_path "$ORIGINAL" "$REQUESTED" p)
            apply_wallpaper "$land_img" "$( [ -f "$portrait_img" ] && echo "$portrait_img" )"
            warm_other_logos "$ORIGINAL" "$REQUESTED"
        fi
        ;;

    --restore)
        if [ -f "$LAST_WALL" ]; then
            exec "$0" "$(cat "$LAST_WALL")"
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
        echo "Usage: wallpaper-set.sh <image>"
        echo "       wallpaper-set.sh --toggle-logo [arch|rebel|imperial]"
        echo "       wallpaper-set.sh --restore"
        echo "       wallpaper-set.sh --status"
        exit 1
        ;;

    *)
        WALLPAPER="$1"

        if [ ! -f "$WALLPAPER" ]; then
            echo "Error: file not found: $WALLPAPER" >&2
            exit 1
        fi

        echo "$WALLPAPER" > "$LAST_WALL"
        # Repoint the stable symlink hyprlock's background reads (raw wallpaper,
        # no logo overlay — matches the prior swaylock --image behaviour).
        ln -sfn "$WALLPAPER" "$CURRENT_LINK"

        CURRENT="$(active_logo)"
        if [ -n "$CURRENT" ]; then
            composite_logo "$WALLPAPER" "$CURRENT"
            land_img=$(composed_path "$WALLPAPER" "$CURRENT" l)
            portrait_img=$(composed_path "$WALLPAPER" "$CURRENT" p)
            apply_wallpaper "$land_img" "$( [ -f "$portrait_img" ] && echo "$portrait_img" )"
        else
            apply_wallpaper "$WALLPAPER"
        fi
        # Warm other logos in the background so the next logo switch is instant
        warm_other_logos "$WALLPAPER" "$CURRENT"
        ;;
esac
