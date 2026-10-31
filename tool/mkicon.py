from PIL import Image, ImageDraw, ImageChops, ImageOps, ImageFilter
S = 4                      # supersampling
N = 1024 * S

def sc(v): return int(round(v * S))

def circle_mask(cx, cy, r):
    m = Image.new("L", (N, N), 0)
    ImageDraw.Draw(m).ellipse([sc(cx - r), sc(cy - r), sc(cx + r), sc(cy + r)], fill=255)
    return m

def vgrad(c1, c2):
    g = Image.linear_gradient("L").resize((N, N))          # black(top) -> white(bottom)
    return ImageOps.colorize(g, c1, c2).convert("RGBA")

def dgrad(c1, c2):
    import numpy as np
    a = np.array([int(c1[i:i+2], 16) for i in (1, 3, 5)], dtype=float)
    b = np.array([int(c2[i:i+2], 16) for i in (1, 3, 5)], dtype=float)
    y, x = np.mgrid[0:N, 0:N]
    t = ((x + y) / (2.0 * (N - 1)))[..., None]
    rgb = (a + (b - a) * t).astype("uint8")
    alpha = np.full((N, N, 1), 255, dtype="uint8")
    return Image.fromarray(np.concatenate([rgb, alpha], axis=2), "RGBA")

def mark_layer():
    outer = circle_mask(512, 512, 330)
    cut = circle_mask(652, 470, 285)
    crescent = ImageChops.subtract(outer, cut)
    layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    layer.paste(vgrad("#EADDFF", "#9B6BFF"), (0, 0), crescent)
    # play triangle: polygon + round-join stroke (matches the Dart painter)
    pts = [(537, 430), (537, 594), (682, 512)]
    tri = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(tri)
    d.polygon([(sc(x), sc(y)) for x, y in pts], fill=255)
    w = 36
    for i in range(3):
        a, b = pts[i], pts[(i + 1) % 3]
        d.line([(sc(a[0]), sc(a[1])), (sc(b[0]), sc(b[1]))], fill=255, width=sc(w))
        d.ellipse([sc(a[0] - w / 2), sc(a[1] - w / 2), sc(a[0] + w / 2), sc(a[1] + w / 2)], fill=255)
    layer.paste(Image.new("RGBA", (N, N), "#F3ECFF"), (0, 0), tri)
    return layer

def with_bg(mark):
    rr = Image.new("L", (N, N), 0)
    ImageDraw.Draw(rr).rounded_rectangle([0, 0, N - 1, N - 1], radius=sc(230), fill=255)
    bg = dgrad("#3A1D78", "#14092B")
    out = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    out.paste(bg, (0, 0), rr)
    out.alpha_composite(mark)
    return out

mark = mark_layer()
full = with_bg(mark).resize((1024, 1024), Image.LANCZOS)
full.save("assets/icon/icon.png")

# Android adaptive foreground: mark only, scaled into the safe zone
small = mark.resize((int(N * 0.8), int(N * 0.8)), Image.LANCZOS)
fg = Image.new("RGBA", (N, N), (0, 0, 0, 0))
off = (N - small.width) // 2
fg.alpha_composite(small, (off, off))
fg.resize((1024, 1024), Image.LANCZOS).save("assets/icon/icon_foreground.png")

full.save("windows/runner/resources/app_icon.ico",
          sizes=[(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (16, 16)])
print("ok")
