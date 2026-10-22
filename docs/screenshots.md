# README screenshots

`scripts/readme-shots.sh` renders every screenshot in the README with `scripts/shot.sh`.
Each shot runs in its own headless compositor with the GPU renderer and layer blur, at 1920x1080.

```sh
scripts/readme-shots.sh ~/shots            # all shots
scripts/readme-shots.sh ~/shots launcher   # one shot by name
```

Data is fixture data. The dashboard scans demo git repos made in a temp dir.
The wallpaper is `wallpapers/pexels-eberhardgross-1287145.jpg`. Edit mode renders with `--fresh`,
so no local plugin shows up.

Needs a readable `/dev/dri` render node for the `gles2` renderer.

## Into the README

Each image is resized to 1600 px wide and reduced to 256 colours:

```sh
magick ~/shots/launcher.png -resize 1600x -colors 256 PNG8:docs/img/launcher.png
```

`themes.png` and `packs.png` crop the dashboard panel (`-crop 990x612+465+462`) from the
`theme-*`, `grimdark` and `hud` shots and tile them with `magick montage`.

`docs/img/header.svg` is plain SVG rects (5x7 pixel letters). It renders the same on GitHub light and dark.
