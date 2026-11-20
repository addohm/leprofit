"""Draws the leProfit icon into art/ (512, 400, 256 and 128 px PNGs; 400 is the CurseForge and Wago
avatar), the in-game icon leProfit/Media/Icon.tga (128 px; the game reads TGA with power-of-two
sizes; the .toc's IconTexture, the window, the minimap button and the profession window's button
use it), and the listing banner art/leprofit-banner.png (1600x500: the icon, the name, the tagline
and a sample of the Crafts list).

The design: a gold coin with a rising arrow on it (a craft that makes gold), on a deep green
rounded square. The same build as Leboof's and Leproc's icons, our own art.

Needs Pillow, and the Inter font for the banner (bold and semibold): it looks in .scratch/fonts/
(Inter-Bold.ttf, Inter-SemiBold.ttf), or point LEPROFIT_FONT_BOLD and LEPROFIT_FONT_SEMI at the files.
Run: python3 art/make_logo.py
"""
import os
import pathlib

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
ART = ROOT / "art"
GAME_ICON = ROOT / "leProfit" / "Media" / "Icon.tga"
S = 2048  # draw big, downsample for smooth edges

GREEN_TOP = (30, 104, 66)
GREEN_BOT = (8, 30, 20)
RIM = (130, 220, 160)
GOLD_TOP = (255, 226, 130)
GOLD_BOT = (214, 150, 40)
GOLD_DEEP = (150, 96, 18)
GLOW = (255, 200, 90)
ARROW = (22, 84, 50)


def vgrad(w, h, top, bot):
    g = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / (h - 1)
        g.putpixel((0, y), tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
    return g.resize((w, h))


def rounded_mask(box, radius):
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, radius=radius, fill=255)
    return mask


def draw_icon():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    pad, radius = 40, 360
    body = rounded_mask([pad, pad, S - pad, S - pad], radius)

    # Background: green gradient, a soft light from the top, a thin bright rim.
    bg = vgrad(S, S, GREEN_TOP, GREEN_BOT).convert("RGBA")
    light = Image.new("L", (S, S), 0)
    ImageDraw.Draw(light).ellipse([-S * 0.2, -S * 0.75, S * 1.2, S * 0.55], fill=60)
    light = light.filter(ImageFilter.GaussianBlur(160))
    bg = Image.composite(Image.new("RGBA", (S, S), (255, 255, 255, 255)), bg, light)
    img.paste(bg, (0, 0), body)
    rim = ImageChops.subtract(body, rounded_mask([pad + 34, pad + 34, S - pad - 34, S - pad - 34], radius - 34))
    img.paste(Image.new("RGBA", (S, S), RIM + (255,)), (0, 0), rim.point(lambda v: v * 0.5))

    # The coin: a gold disc with a darker ring inside its edge.
    cx, cy, r = S / 2, S / 2, 640
    coin = Image.new("L", (S, S), 0)
    ImageDraw.Draw(coin).ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    shadow = coin.filter(ImageFilter.GaussianBlur(50)).point(lambda v: v * 0.6)
    img.paste(Image.new("RGBA", (S, S), (0, 0, 0, 255)), (0, 60), shadow)
    glow = coin.filter(ImageFilter.GaussianBlur(120)).point(lambda v: v * 0.45)
    img.paste(Image.new("RGBA", (S, S), GLOW + (255,)), (0, 0), ImageChops.multiply(glow, body))
    img.paste(vgrad(S, S, GOLD_TOP, GOLD_BOT).convert("RGBA"), (0, 0), coin)
    ring = Image.new("L", (S, S), 0)
    ImageDraw.Draw(ring).ellipse([cx - r + 90, cy - r + 90, cx + r - 90, cy + r - 90], outline=255, width=46)
    img.paste(Image.new("RGBA", (S, S), GOLD_DEEP + (255,)), (0, 0), ring.point(lambda v: v * 0.8))

    # The rising arrow on the coin: a zigzag line up to the right, ending in an arrowhead.
    arrow = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(arrow)
    pts = [(cx - 380, cy + 250), (cx - 110, cy - 20), (cx + 40, cy + 120), (cx + 300, cy - 160)]
    d.line(pts, fill=255, width=120, joint="curve")
    for p in pts[:-1]:
        d.ellipse([p[0] - 60, p[1] - 60, p[0] + 60, p[1] + 60], fill=255)
    tip = (cx + 400, cy - 260)
    d.polygon([tip, (cx + 120, cy - 230), (cx + 370, cy + 20)], fill=255)
    img.paste(Image.new("RGBA", (S, S), ARROW + (255,)), (0, 0), ImageChops.multiply(arrow, coin))

    # Keep everything inside the rounded square.
    img.putalpha(ImageChops.multiply(img.getchannel("A"), body))
    return img


FONTS = ROOT / ".scratch" / "fonts"
BOLD = os.environ.get("LEPROFIT_FONT_BOLD", str(FONTS / "Inter-Bold.ttf"))
SEMI = os.environ.get("LEPROFIT_FONT_SEMI", str(FONTS / "Inter-SemiBold.ttf"))
TAGLINE = "Which crafts make gold, most profitable first."
# A sample of the Crafts list: item, cost, buyout, profit.
SAMPLE = [
    ("Runecloth Bag", "2g 10s", "6g 40s", "+3g 98s"),
    ("Mithril Spurs", "4g 75s", "9g 20s", "+3g 99s"),
    ("Elixir of Fortitude", "36s", "1g 10s", "+68s"),
]


def banner(icon):
    from PIL import ImageFont
    W, H = 1600, 500
    img = vgrad(W, H, GREEN_TOP, GREEN_BOT).convert("RGBA")
    light = Image.new("L", (W, H), 0)
    ImageDraw.Draw(light).ellipse([-200, -500, 1100, 300], fill=50)
    light = light.filter(ImageFilter.GaussianBlur(120))
    img = Image.composite(Image.new("RGBA", (W, H), (255, 255, 255, 255)), img, light)
    img.alpha_composite(icon.resize((380, 380), Image.LANCZOS), (60, 60))
    d = ImageDraw.Draw(img)
    title = ImageFont.truetype(BOLD, 140)
    tag = ImageFont.truetype(SEMI, 44)
    row = ImageFont.truetype(SEMI, 30)
    d.text((500, 52), "leProfit", font=title, fill=GOLD_TOP)
    d.line([(506, 228), (1530, 228)], fill=GOLD_BOT + (255,), width=3)
    d.text((506, 244), TAGLINE, font=tag, fill=(222, 240, 228))
    # The sample rows, with the columns right-aligned like the addon's.
    cols = (1080, 1270, 1500)
    y = 322
    for name, cost, buyout, profit in SAMPLE:
        d.text((510, y), name, font=row, fill=(30, 255, 0))
        for x, text, color in zip(cols, (cost, buyout, profit), ((230, 230, 230), (230, 230, 230), GOLD_TOP)):
            w = d.textlength(text, font=row)
            d.text((x - w, y), text, font=row, fill=color)
        y += 46
    img.convert("RGB").save(ART / "leprofit-banner.png")
    # Checks without looking at it: the text fits, the rows sit inside the canvas.
    tb = d.textbbox((500, 52), "leProfit", font=title)
    tg = d.textbbox((506, 244), TAGLINE, font=tag)
    print("title", tb, "tagline", tg, "fits:", tg[2] < W - 40 and tb[3] < 228, "rows end at y", y)


def main():
    ART.mkdir(exist_ok=True)
    big = draw_icon()
    for px in (512, 400, 256, 128):
        big.resize((px, px), Image.LANCZOS).save(ART / f"leprofit-icon-{px}.png")
    GAME_ICON.parent.mkdir(exist_ok=True)
    big.resize((128, 128), Image.LANCZOS).save(GAME_ICON)
    print(f"Wrote art/leprofit-icon-{{512,400,256,128}}.png and {GAME_ICON.relative_to(ROOT)}")
    if os.path.exists(BOLD) and os.path.exists(SEMI):
        banner(big)
        print("Wrote art/leprofit-banner.png")
    else:
        print("No Inter font files (.scratch/fonts, or LEPROFIT_FONT_BOLD and LEPROFIT_FONT_SEMI): skipped the banner")


if __name__ == "__main__":
    main()
