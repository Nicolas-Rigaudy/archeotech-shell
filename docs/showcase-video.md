# Showcase video

The README opens with one short video (about 50 s) that tours the shell. It is recorded on a real desk:
headless capture reaches only 20 to 28 fps and looks choppy. Captions and title cards are added after.

## Before recording

- Base pack, a dark theme (Catppuccin Macchiato, mauve accent), glass on.
- A free wallpaper from `wallpapers/`.
- No private data on screen: clear notifications, check what the dashboard's project list shows.
- One empty tag to start from. Close the terminal you start the recording from.

## Record

```sh
sleep 5; timeout -s INT 75 wf-recorder -o eDP-1 -c libx264 -p preset=ultrafast -p crf=14 -f ~/Videos/archeotech-take.mkv
```

`wf-recorder -L` lists the outputs. The 5 s delay lets you switch to the empty tag. Recording stops by itself after 75 s.
Move the mouse slowly and pause about a second after each panel opens. Do a short test take first to check the cursor shows.

## Shot list

| Time | Action | Caption |
|---|---|---|
| 0-4 s | Empty desktop, the cursor rests on the bar | title card: ARCHEOTECH |
| 4-10 s | Hover two bar widgets, then `Super + Home` | Dashboard |
| 10-16 s | `Super + R`, type `kit`, Enter | Launcher |
| 16-24 s | `Super + W`, click two wallpapers | Wallpapers |
| 24-32 s | `Super + ,`, Appearance: switch flavor to Latte, change the accent, back to Macchiato | One theme, every app |
| 32-40 s | `Super + Shift + E`, drag a widget from the library onto the bar | Arrange with the mouse |
| 40-46 s | `Super + K`, hover a combo so the keyboard lights up | Every bind, one key away |
| 46-50 s | Close everything, back to the empty desktop | repo URL card |

## After

The take is cut, captioned and compressed to an mp4 under 10 MB. Drop it into the README on github.com
(edit the file in the browser and drag the mp4 in). GitHub uploads it and inserts a bare `user-attachments` URL,
which replaces the placeholder screenshot at the top of the README.
