"""Original procedural cyberdeck wallpapers (no third-party art).

Regenerates packs/cyberdeck/walls/ (run from the repo root):
    python3 -I packs/cyberdeck/kit/gen_walls.py packs/cyberdeck/walls [scene ...]
Scenes and the file each writes: alley -> netrunner.png, monolith -> megacorp.png,
terrain -> deck.png, orbital -> orbital.png, circuit -> circuit.png.
Seeded, so a rerun gives the same images. Needs numpy and Pillow.
"""
import math, random, sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops, ImageFont

W, H = 1920, 1200
FONT = str(Path(__file__).resolve().parent.parent / "fonts" / "ShareTechMono-Regular.ttf")
YY, XX = np.mgrid[0:H, 0:W].astype(np.float32)


def img(a): return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
def arr(im): return np.asarray(im.convert("RGB"), np.float32) / 255
def col(c, a=1.0): return np.array(c, np.float32) / 255 * a


def noise(seed, scale, octaves=4):
    rng = np.random.default_rng(seed); out = np.zeros((H, W), np.float32); amp = tot = 1.0; tot = 0
    for _ in range(octaves):
        g = rng.random((int(H / scale) + 3, int(W / scale) + 3)).astype(np.float32)
        out += amp * np.asarray(Image.fromarray(g, "F").resize((W, H), Image.BICUBIC)); tot += amp
        amp *= 0.5; scale = max(2, scale / 2)
    return out / tot


def vgrad(stops):
    ts = [s[0] for s in stops]; cs = np.array([s[1] for s in stops], np.float32) / 255
    t = np.linspace(0, 1, H)
    return np.stack([np.interp(t, ts, cs[:, i]) for i in range(3)], -1)[:, None, :].repeat(W, 1)


def blob(cx, cy, rx, ry, c, a=1.0):
    return np.exp(-(((XX - cx) / rx) ** 2 + ((YY - cy) / ry) ** 2))[..., None] * col(c, a)


def glow(layer, *radii):
    out = arr(layer)
    for r, k in radii: out = out + arr(layer.filter(ImageFilter.GaussianBlur(r))) * k
    return out


def finish(a, seed, ca=2, grain=0.035, vig=0.55):
    v = 1 - vig * (((XX - W / 2) / (W * 0.62)) ** 2 + ((YY - H / 2) / (H * 0.7)) ** 2)
    a = a * np.clip(v, 0, 1)[..., None]
    if ca:  # slight chromatic split
        a[..., 0] = np.roll(a[..., 0], ca, 1); a[..., 2] = np.roll(a[..., 2], -ca, 1)
    a = a + (np.random.default_rng(seed).random((H, W, 1), np.float32) - 0.5) * grain
    return img(a)


def rain(seed, n, color, k, slant=0.12, lmin=18, lmax=70):
    rnd = random.Random(seed); L = Image.new("RGB", (W, H)); d = ImageDraw.Draw(L)
    for _ in range(n):
        x, y, l = rnd.uniform(-100, W), rnd.uniform(-80, H), rnd.uniform(lmin, lmax)
        c = tuple(int(v * rnd.uniform(0.3, 1)) for v in color)
        d.line([(x, y), (x + l * slant, y + l)], fill=c, width=1)
    return arr(L.filter(ImageFilter.GaussianBlur(0.6))) * k


# --------------------------------------------------------------------------- alley
def alley():
    rnd = random.Random(11); vx, vy, f = 960, 560, 900
    P = lambda X, Y, z: (vx + X / z * f, vy + Y / z * f)
    a = vgrad([(0, (5, 4, 14)), (0.3, (16, 7, 34)), (0.46, (70, 16, 70)), (0.5, (30, 10, 34)), (1, (4, 3, 8))])
    a += blob(960, 500, 360, 230, (255, 40, 150), 0.55) + blob(1020, 440, 220, 170, (40, 210, 255), 0.35)
    sky = img(a); d = ImageDraw.Draw(sky)
    # distant spire in the gap
    d.polygon([(948, 560), (962, 90), (976, 560)], fill=(8, 6, 14)); d.line([(962, 90), (962, 30)], fill=(10, 8, 16), width=2)
    neon = Image.new("RGB", (W, H)); nd = ImageDraw.Draw(neon)
    nd.ellipse([958, 26, 966, 34], fill=(255, 40, 60))
    for y in range(140, 540, 22): nd.line([(962 - (y - 90) * 14 / 470, y), (962 + (y - 90) * 14 / 470, y)], fill=(30, 140, 170))
    win = Image.new("RGB", (W, H)); wd = ImageDraw.Draw(win)
    pal = [(255, 40, 150), (40, 230, 255), (255, 60, 70), (250, 220, 80), (180, 80, 255)]
    for side in (-1, 1):
        z = 90.0
        segs = []
        while z > 1.0:
            z0 = max(1.0, z - rnd.uniform(4, 12) * (z / 30 + 0.3)); segs.append((z0, z)); z = z0
        for z0, z1 in segs:  # far to near
            X = side * (5 + rnd.uniform(0, 1.4)); top = -rnd.uniform(9, 42)
            shade = tuple(int(v * rnd.uniform(0.7, 1.2)) for v in (11, 8, 20))
            d.polygon([P(X, top, z0), P(X, top, z1), P(X, 3, z1), P(X, 3, z0)], fill=shade)
            d.line([P(X, top, z0), P(X, top, z1)], fill=(30, 18, 44), width=1)
            fy = top + 1
            while fy < 1.5 and z1 > 7:
                zz = z0 + 0.3
                while zz < z1 - 0.5:
                    if rnd.random() < 0.22 and zz > 6:
                        c = rnd.choice([(255, 190, 120), (120, 220, 255), (255, 120, 200), (60, 70, 90)])
                        c = tuple(int(v * rnd.uniform(0.15, 0.45) * min(1, 14 / zz)) for v in c)
                        wd.polygon([P(X, fy, zz), P(X, fy, zz + 0.45), P(X, fy + 0.55, zz + 0.45), P(X, fy + 0.55, zz)], fill=c)
                    zz += 0.75
                fy += 1.1
            if rnd.random() < 0.6 and 5 < z0 < 40:  # protruding vertical sign
                zc = (z0 + z1) / 2; y0 = rnd.uniform(-14, -4); h = rnd.uniform(3, 7); c = rnd.choice(pal)
                Xi = X - side * rnd.uniform(1.0, 1.6)
                q = [P(X, y0, zc), P(Xi, y0, zc), P(Xi, y0 + h, zc), P(X, y0 + h, zc)]
                d.polygon(q, fill=(6, 4, 10)); nd.polygon(q, outline=c, width=max(1, int(4 / zc)))
                for k in range(int(h / 0.9)):  # glyph blocks (no real text)
                    gy = y0 + 0.35 + k * 0.9
                    for _ in range(rnd.randint(2, 4)):
                        u0 = rnd.uniform(0.15, 0.6); u1 = min(0.88, u0 + rnd.uniform(0.1, 0.35)); v0 = rnd.uniform(0, 0.4)
                        Xa, Xb = X + (Xi - X) * u0, X + (Xi - X) * u1
                        nd.polygon([P(Xa, gy + v0, zc), P(Xb, gy + v0, zc), P(Xb, gy + v0 + 0.12, zc), P(Xa, gy + v0 + 0.12, zc)], fill=c)
            if rnd.random() < 0.35 and 6 < z0 < 60:  # flush tube band on the facade
                y = rnd.uniform(-6, -1); c = rnd.choice(pal)
                nd.line([P(X, y, z0 + 0.4), P(X, y, z1 - 0.4)], fill=c, width=max(1, int(6 / z0)))
    a = arr(sky) + arr(win) + glow(win, (3, 0.5)) + glow(neon, (4, 1.2), (18, 0.8), (60, 0.5))
    # wet street: mirror about the horizon, smeared and darkened
    street = Image.new("L", (W, H)); ImageDraw.Draw(street).polygon([P(-5, 3, 90), P(-5, 3, 0.8), P(5, 3, 0.8), P(5, 3, 90)], fill=255)
    m = np.asarray(street.filter(ImageFilter.GaussianBlur(1)), np.float32)[..., None] / 255
    src = np.clip(2 * vy - np.arange(H), 0, H - 1).astype(int)
    refl = img(a[src]).filter(ImageFilter.GaussianBlur(2)).resize((W, H // 14), Image.BILINEAR).resize((W, H), Image.BICUBIC)
    wet = 0.25 + 0.55 * np.clip((noise(3, 160, 5) - 0.42) * 4, 0, 1)
    ground = arr(refl) * wet[..., None] * np.clip((YY - vy) / 300, 0.2, 1)[..., None] + col((8, 7, 12))
    a = a * (1 - m) + ground * m
    ld = Image.new("RGB", (W, H)); ldd = ImageDraw.Draw(ld)
    zz = 1.2
    while zz < 60: ldd.polygon([P(-0.08, 3, zz), P(0.08, 3, zz), P(0.08, 3, zz + 1.2), P(-0.08, 3, zz + 1.2)], fill=(70, 60, 50)); zz += 3
    a += arr(ld) * 0.6
    a += blob(960, 560, 700, 90, (255, 60, 160), 0.18) + noise(5, 300, 3)[..., None] * col((60, 20, 70), 0.25) * (YY < vy + 200)[..., None]
    a += rain(12, 3200, (190, 210, 255), 0.4)
    out = img(a); od = ImageDraw.Draw(out)
    for zc, sag, w in [(6, 60, 3), (11, 40, 2), (18, 25, 2), (3.2, 140, 5)]:  # overhead cables
        x0, y0 = P(-5, -9, zc); x1, y1 = P(5, -10, zc)
        pts = [(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t + sag * 4 * t * (1 - t)) for t in np.linspace(0, 1, 60)]
        od.line(pts, fill=(4, 3, 6), width=w)
    return finish(arr(out), 11)


# ------------------------------------------------------------------------ monolith
def monolith():
    rnd = random.Random(21)
    a = vgrad([(0, (2, 2, 3)), (0.55, (10, 5, 7)), (0.85, (38, 8, 12)), (1, (10, 3, 5))])
    a += blob(960, 1180, 1100, 260, (220, 20, 40), 0.45) + noise(4, 260, 4)[..., None] * col((60, 14, 20), 0.35) * np.clip((YY - 500) / 700, 0, 1)[..., None]
    beams = Image.new("RGB", (W, H)); bd = ImageDraw.Draw(beams)
    for x0, ang in [(380, -0.42), (1560, 0.36), (180, -0.15)]:
        ex = x0 + math.tan(ang) * 1300
        bd.polygon([(x0 - 6, 1200), (x0 + 6, 1200), (ex + 70, -100), (ex - 70, -100)], fill=(70, 60, 70))
    a += arr(beams.filter(ImageFilter.GaussianBlur(26))) * 0.55
    base = img(a); d = ImageDraw.Draw(base)
    lights = Image.new("RGB", (W, H)); ld = ImageDraw.Draw(lights)
    # side towers
    for x, w, top in [(80, 170, 520), (300, 120, 640), (1500, 150, 560), (1700, 200, 430), (1380, 90, 760), (520, 90, 820)]:
        d.rectangle([x, top, x + w, H], fill=(6, 4, 6)); ld.ellipse([x + w // 2 - 3, top - 3, x + w // 2 + 3, top + 3], fill=(255, 30, 40))
        for _ in range(int(w * (H - top) / 900)):
            wx, wy = rnd.randint(x + 6, x + w - 8), rnd.randint(top + 10, H)
            ld.rectangle([wx, wy, wx + 2, wy + 1], fill=tuple(int(v * rnd.uniform(0.2, 0.6)) for v in (255, 200, 170)))
    # the monolith: looking up, edges converge to a far vanishing point
    vpx, vpy = 960, -3200
    def edge(x0, y): return x0 + (vpx - x0) * (1200 - y) / (1200 - vpy)
    top = 70
    L, C, R = 640, 1010, 1300
    d.polygon([(L, 1200), (C, 1200), (edge(C, top), top), (edge(L, top), top)], fill=(9, 8, 10))
    d.polygon([(C, 1200), (R, 1200), (edge(R, top), top), (edge(C, top), top)], fill=(16, 10, 12))
    y = 1200.0; k = 0; step = 34.0
    while y > top + 4:
        lx, cx, rx = edge(L, y), edge(C, y), edge(R, y)
        ring = k % 11 == 5
        ld.line([(lx, y), (cx, y)], fill=(255, 30, 50) if ring else (40, 10, 14), width=2 if ring else 1)
        ld.line([(cx, y), (rx, y)], fill=(200, 25, 40) if ring else (55, 14, 18), width=2 if ring else 1)
        if not ring and rnd.random() < 0.6:
            for _ in range(rnd.randint(1, 4)):
                t = rnd.random(); wx = lx + (rx - lx) * t
                ld.rectangle([wx, y - step * 0.55, wx + 3, y - step * 0.35], fill=(120, 110, 100))
        y -= step; step = max(9, step * 0.955); k += 1
    for t in np.linspace(0, 1, 26)[1:-1]:
        for x0, x1 in ((L, C), (C, R)):
            xb = x0 + (x1 - x0) * t; ld.line([(xb, 1200), (edge(xb, top), top)], fill=(26, 8, 11), width=1)
    ld.line([(C, 1200), (edge(C, top), top)], fill=(170, 30, 40), width=2)
    ld.line([(R, 1200), (edge(R, top), top)], fill=(110, 20, 28), width=1)
    ld.line([(L, 1200), (edge(L, top), top)], fill=(60, 14, 18), width=1)
    # crown: a slit "eye" and the antenna
    ex0, ex1 = edge(L, 150), edge(R, 150)
    d.rectangle([ex0, top, ex1, 200], fill=(4, 3, 4))
    ld.rectangle([ex0 + 60, 168, ex1 - 60, 174], fill=(255, 40, 60))
    d.line([(edge(C, top), top), (edge(C, top), 0)], fill=(12, 8, 10), width=4)
    ld.ellipse([edge(C, top) - 4, 8, edge(C, top) + 4, 16], fill=(255, 30, 40))
    a = arr(base) + glow(lights, (3, 0.9), (14, 0.6), (50, 0.35))
    fog = noise(8, 200, 5)[..., None] * col((140, 40, 50), 0.4) * np.clip((YY - 800) / 400, 0, 1)[..., None]
    a += fog + rain(22, 1800, (200, 160, 160), 0.25, slant=0.05)
    return finish(a, 21, grain=0.04)


# ------------------------------------------------------------------------- terrain
def terrain():
    vx, vy, f = 960, 430, 1100
    a = vgrad([(0, (1, 6, 3)), (0.36, (4, 22, 10)), (0.42, (2, 10, 5)), (1, (0, 3, 1))])
    a += blob(960, 430, 900, 120, (40, 255, 120), 0.12)
    sky = img(a); d = ImageDraw.Draw(sky); lines = Image.new("RGB", (W, H)); ld = ImageDraw.Draw(lines)
    # moon ring with ticks
    ld.ellipse([1290, 110, 1530, 350], outline=(60, 255, 130), width=2)
    for i in range(72):
        t = i / 72 * 2 * math.pi; r0, r1 = 128, 138 if i % 6 else 152
        ld.line([(1410 + r0 * math.cos(t), 230 + r0 * math.sin(t)), (1410 + r1 * math.cos(t), 230 + r1 * math.sin(t))], fill=(40, 180, 90), width=1)
    hf = noise(31, 90, 5); hf2 = noise(32, 30, 3)
    nx, nz = 180, 96; xs = np.linspace(-70, 70, nx); zs = np.geomspace(2.2, 140, nz)
    def h(ix, iz):
        u = int((ix / (nx - 1)) * (W - 1)); v = int((iz / (nz - 1)) * (H - 1))
        valley = min(1, abs(xs[ix]) / 18) ** 1.6
        return (hf[v, u] - 0.35) * 26 * valley + hf2[v, u] * 2
    pts = [[(vx + xs[i] / zs[j] * f, vy + (4.5 - h(i, j)) / zs[j] * f) for i in range(nx)] for j in range(nz)]
    for j in range(nz - 2, -1, -1):  # far to near, painter's
        fade = 1 - j / nz
        c = tuple(int(v * (0.25 + 0.75 * (1 - fade) ** 0.5)) for v in (60, 255, 130))
        for i in range(nx - 1):
            q = [pts[j][i], pts[j][i + 1], pts[j + 1][i + 1], pts[j + 1][i]]
            if max(p[1] for p in q) < 0 or min(p[0] for p in q) > W + 200 or max(p[0] for p in q) < -200: continue
            d.polygon(q, fill=(1, 6, 3)); ld.polygon(q, fill=(0, 0, 0), outline=c)  # fill occludes farther lines
    # amber waypoint on a peak
    pk = max(((i, j) for j in range(10, 30) for i in range(20, nx - 20)), key=lambda t: -pts[t[1]][t[0]][1])
    px, py = pts[pk[1]][pk[0]]
    amb = Image.new("RGB", (W, H)); ad = ImageDraw.Draw(amb)
    for s in (1, -1):
        ad.line([(px + s * 26, py - 26), (px + s * 14, py - 26)], fill=(255, 180, 60), width=2)
        ad.line([(px + s * 26, py - 26), (px + s * 26, py - 14)], fill=(255, 180, 60), width=2)
        ad.line([(px + s * 26, py + 26), (px + s * 14, py + 26)], fill=(255, 180, 60), width=2)
        ad.line([(px + s * 26, py + 26), (px + s * 26, py + 14)], fill=(255, 180, 60), width=2)
    ad.line([(px + 26, py - 26), (px + 90, py - 80), (px + 260, py - 80)], fill=(255, 180, 60), width=1)
    ad.text((px + 96, py - 104), "WAYPOINT 07 // ELEV 2214 M", font=ImageFont.truetype(FONT, 20), fill=(255, 190, 80))
    a = arr(sky) + glow(lines, (2, 0.8), (10, 0.5)) + glow(amb, (3, 0.8), (12, 0.4))
    a *= (1 - 0.35 * ((YY.astype(int) % 3) == 0))[..., None]  # scanlines
    return finish(a, 31, ca=1, grain=0.03)


# ------------------------------------------------------------------------- orbital
def orbital():
    rnd = random.Random(41); rng = np.random.default_rng(41)
    a = vgrad([(0, (1, 2, 6)), (1, (3, 6, 14))]) + noise(42, 400, 4)[..., None] * col((40, 20, 70), 0.25)
    st = Image.new("RGB", (W, H)); sd = ImageDraw.Draw(st)
    for _ in range(2600):
        x, y, b = rnd.uniform(0, W), rnd.uniform(0, H), rnd.random() ** 4
        sd.point((x, y), fill=tuple(int(v * (0.2 + 0.8 * b)) for v in (220, 230, 255)))
    a += glow(st, (1.2, 0.7))
    cx, cy, R = 760, 3300, 2580
    dist = np.sqrt((XX - cx) ** 2 + (YY - cy) ** 2) - R
    inside = (dist < 0)[..., None].astype(np.float32)
    land = np.clip((noise(43, 220, 5) - 0.5) * 5, 0, 1)
    cities = (rng.random((H, W)) < 0.012 * land) * rng.random((H, W))
    cimg = img(np.stack([cities * 1.0, cities * 0.7, cities * 0.35], -1)).filter(ImageFilter.GaussianBlur(0.8))
    planet = col((3, 6, 12)) + land[..., None] * col((6, 12, 16)) + glow(cimg, (3, 1.5)) * 1.6
    a = a * (1 - inside) + planet * inside
    lit = np.clip((XX - 900) / 1100, 0, 1)
    rim = np.exp(-np.abs(dist) / 6)[..., None] * col((120, 230, 255)) * 0.9
    halo = np.exp(-np.clip(dist, 0, None) / 55)[..., None] * (1 - inside) * col((30, 120, 255), 0.7)
    dawn = (np.exp(-np.abs(dist) / 40) * lit)[..., None] * col((255, 140, 60), 0.8)
    a += rim + halo + dawn
    hud = Image.new("RGB", (W, H)); hd = ImageDraw.Draw(hud)
    for rx, ry, rot, c in [(1500, 300, -0.10, (40, 200, 255)), (1100, 520, 0.05, (60, 150, 220))]:
        pts = [(cx + rx * math.cos(t) * math.cos(rot) - ry * math.sin(t) * math.sin(rot) + 200,
                700 + rx * math.cos(t) * math.sin(rot) + ry * math.sin(t) * math.cos(rot)) for t in np.linspace(0, 2 * math.pi, 400)]
        for i in range(0, 399, 2): hd.line([pts[i], pts[i + 1]], fill=c, width=1)
    sx, sy = 1340, 380  # station
    hd.rectangle([sx - 30, sy - 4, sx + 30, sy + 4], fill=(90, 100, 120))
    for s in (-1, 1):
        hd.rectangle([sx + s * 40 - 18, sy - 22, sx + s * 40 + 18, sy + 22], outline=(80, 160, 220), fill=(20, 40, 70))
        hd.line([(sx + s * 30, sy), (sx + s * 22, sy)], fill=(90, 100, 120), width=2)
    hd.ellipse([sx - 3, sy - 3, sx + 3, sy + 3], fill=(255, 60, 70))
    for s1 in (-1, 1):
        for s2 in (-1, 1):
            bx, by = sx + s1 * 90, sy + s2 * 50
            hd.line([(bx, by), (bx - s1 * 18, by)], fill=(46, 242, 255), width=2); hd.line([(bx, by), (bx, by - s2 * 14)], fill=(46, 242, 255), width=2)
    fnt = ImageFont.truetype(FONT, 18)
    hd.line([(sx + 90, sy - 50), (sx + 150, sy - 110), (sx + 380, sy - 110)], fill=(46, 242, 255), width=1)
    hd.text((sx + 156, sy - 134), "TRACK 2F // ALT 412 KM", font=fnt, fill=(140, 245, 255))
    hd.text((sx + 156, sy - 104), "LOCK  0.997", font=fnt, fill=(247, 226, 73))
    a += glow(hud, (2, 0.6), (8, 0.3))
    return finish(a, 41, ca=1, grain=0.025, vig=0.4)


# ------------------------------------------------------------------------- circuit
def circuit():
    rnd = random.Random(51); g = 24; gw, gh = W // g + 1, H // g + 1
    a = vgrad([(0, (2, 10, 12)), (1, (1, 5, 7))]) + noise(52, 300, 4)[..., None] * col((10, 40, 50), 0.3)
    dim = Image.new("RGB", (W, H)); dd = ImageDraw.Draw(dim); hot = Image.new("RGB", (W, H)); hd = ImageDraw.Draw(hot)
    used = set()
    chips = []
    for _ in range(7):
        for _try in range(50):
            cw, ch = rnd.randint(4, 9), rnd.randint(3, 7); x0, y0 = rnd.randint(2, gw - cw - 3), rnd.randint(2, gh - ch - 3)
            if not any((i, j) in used for i in range(x0 - 2, x0 + cw + 3) for j in range(y0 - 2, y0 + ch + 3)): break
        chips.append((x0, y0, cw, ch))
        for i in range(x0 - 1, x0 + cw + 2):
            for j in range(y0 - 1, y0 + ch + 2): used.add((i, j))
    dirs = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]
    for n in range(520):
        x, y = rnd.randrange(gw), rnd.randrange(gh)
        if (x, y) in used: continue
        di = rnd.randrange(0, 8, 2); path = [(x, y)]; used.add((x, y))
        for _ in range(rnd.randint(5, 40)):
            if rnd.random() < 0.18: di = (di + rnd.choice([-1, 1])) % 8
            nx_, ny_ = x + dirs[di][0], y + dirs[di][1]
            if (nx_, ny_) in used or not (0 <= nx_ < gw and 0 <= ny_ < gh): break
            x, y = nx_, ny_; path.append((x, y)); used.add((x, y))
        if len(path) < 3: continue
        pts = [(px * g, py * g) for px, py in path]
        r = rnd.random()
        layer, c, w = (hd, (46, 242, 255), 2) if r < 0.08 else (hd, (255, 42, 74), 2) if r < 0.1 else (dd, (18, 70, 80), 2)
        layer.line(pts, fill=c, width=w, joint="curve")
        for (px, py) in (pts[0], pts[-1]):
            layer.ellipse([px - 5, py - 5, px + 5, py + 5], outline=c, width=2)
        if layer is hd:  # a data packet on the trace
            k = rnd.randrange(len(pts)); px, py = pts[k]; hd.ellipse([px - 3, py - 3, px + 3, py + 3], fill=(230, 255, 255))
    fnt = ImageFont.truetype(FONT, 14)
    for i, (x0, y0, cw, ch) in enumerate(chips):
        X0, Y0, X1, Y1 = x0 * g, y0 * g, (x0 + cw) * g, (y0 + ch) * g
        dd.rectangle([X0, Y0, X1, Y1], fill=(4, 14, 16), outline=(30, 110, 120), width=2)
        for px in range(X0 + 8, X1 - 4, 12):
            dd.line([(px, Y0 - 10), (px, Y0)], fill=(40, 120, 130), width=3); dd.line([(px, Y1), (px, Y1 + 10)], fill=(40, 120, 130), width=3)
        dd.text((X0 + 10, Y0 + 8), f"CR-{0x40 + i * 7:02X}", font=fnt, fill=(60, 170, 180))
        if i == 0: hd.rectangle([X0 + 4, Y0 + 4, X1 - 4, Y1 - 4], outline=(46, 242, 255), width=1)
    a += arr(dim) + glow(hot, (2, 0.9), (10, 0.6), (30, 0.3))
    return finish(a, 51, ca=1, grain=0.03)


if __name__ == "__main__":
    out = Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)
    files = {"alley": "netrunner", "monolith": "megacorp", "terrain": "deck",
             "orbital": "orbital", "circuit": "circuit"}
    for n in sys.argv[2:] or list(files):
        globals()[n]().save(out / f"{files[n]}.png", optimize=True); print("ok", n, "->", files[n])
