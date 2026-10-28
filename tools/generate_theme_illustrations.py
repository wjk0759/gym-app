"""Generate the app's original theme illustrations.

Requires Pillow. Outputs 1x/2x/3x PNGs into Assets.xcassets.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "ios" / "FitAI" / "Resources" / "Assets.xcassets"
MASTER = 1600

LIME = (48, 209, 88, 255)
LIME_DARK = (10, 108, 47, 255)
LIME_SOFT = (48, 209, 88, 42)
CREAM = (244, 235, 221, 255)
CREAM_DARK = (213, 197, 174, 255)
CHAR = (17, 20, 24, 255)
CHAR_2 = (31, 37, 43, 255)
CHAR_3 = (44, 52, 60, 255)
GRAY = (126, 139, 151, 255)
CORAL = (255, 126, 105, 255)
SALMON = (238, 139, 116, 255)
YELLOW = (255, 205, 92, 255)
GREEN = (73, 172, 88, 255)
DARK_GREEN = (39, 113, 58, 255)
RED = (232, 78, 74, 255)
WHITE = (255, 255, 255, 255)


def canvas() -> Image.Image:
    return Image.new("RGBA", (MASTER, MASTER), (0, 0, 0, 0))


def rounded(draw: ImageDraw.ImageDraw, box, radius, fill, outline=None, width=0):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def line(draw: ImageDraw.ImageDraw, points, fill, width):
    draw.line(points, fill=fill, width=width, joint="curve")


def star(draw: ImageDraw.ImageDraw, cx: int, cy: int, r: int, color):
    points = []
    for index in range(8):
        radius = r if index % 2 == 0 else max(2, r // 3)
        angle = math.pi * index / 4
        points.append((cx + math.cos(angle) * radius, cy + math.sin(angle) * radius))
    draw.polygon(points, fill=color)


def add_glow(image: Image.Image, box) -> None:
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.ellipse(box, fill=LIME_SOFT)
    image.alpha_composite(layer.filter(ImageFilter.GaussianBlur(70)))


def equipment() -> Image.Image:
    image = canvas()
    add_glow(image, (120, 160, 1480, 1460))
    draw = ImageDraw.Draw(image)

    # Focus brackets
    bracket = 170
    offset = 230
    for sx in (1, -1):
        for sy in (1, -1):
            x = offset if sx == 1 else MASTER - offset
            y = offset if sy == 1 else MASTER - offset
            line(draw, [(x, y), (x, y + sy * bracket)], LIME, 24)
            line(draw, [(x, y), (x + sx * bracket, y)], LIME, 24)

    # Soft shadow under the dumbbell
    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    sdraw.ellipse((430, 1110, 1170, 1210), fill=(0, 0, 0, 75))
    image.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(28)))
    draw = ImageDraw.Draw(image)

    # Dumbbell bar
    rounded(draw, (470, 770, 1130, 860), 44, CHAR)
    rounded(draw, (520, 790, 1080, 840), 24, CHAR_3)
    for x in range(700, 910, 34):
        line(draw, [(x, 792), (x, 838)], GRAY, 8)

    # Left plates
    rounded(draw, (360, 585, 500, 1045), 52, CREAM)
    rounded(draw, (465, 650, 545, 980), 38, LIME)
    rounded(draw, (490, 700, 525, 930), 16, LIME_DARK)
    # Right plates
    rounded(draw, (1100, 585, 1240, 1045), 52, CREAM)
    rounded(draw, (1055, 650, 1135, 980), 38, LIME)
    rounded(draw, (1075, 700, 1110, 930), 16, LIME_DARK)

    # End caps
    rounded(draw, (320, 735, 380, 895), 28, CHAR)
    rounded(draw, (1220, 735, 1280, 895), 28, CHAR)

    star(draw, 300, 400, 34, LIME)
    star(draw, 1300, 410, 24, CREAM)
    star(draw, 1230, 1240, 20, LIME)
    return image


def training() -> Image.Image:
    image = canvas()
    add_glow(image, (120, 140, 1480, 1440))
    draw = ImageDraw.Draw(image)

    # Calendar card
    rounded(draw, (330, 210, 1270, 1190), 72, CHAR_2)
    rounded(draw, (330, 210, 1270, 450), 72, LIME)
    draw.rectangle((330, 340, 1270, 450), fill=LIME)
    rounded(draw, (330, 390, 1270, 1190), 60, CHAR_2)

    for x in (460, 1140):
        draw.ellipse((x - 28, 250, x + 28, 306), fill=CHAR)
        line(draw, [(x, 306), (x, 360)], CHAR, 14)

    # Calendar grid
    for row in range(3):
        for col in range(5):
            x = 430 + col * 158
            y = 500 + row * 170
            rounded(draw, (x, y, x + 105, y + 105), 24, CHAR_3)
            if (row, col) in {(0, 2), (1, 1), (1, 4), (2, 3)}:
                line(draw, [(x + 24, y + 55), (x + 45, y + 77), (x + 83, y + 28)], LIME, 12)

    # Rising trend
    line(draw, [(430, 1110), (640, 980), (800, 1030), (1040, 820), (1180, 870)], LIME, 14)
    draw.polygon([(1180, 870), (1120, 840), (1160, 800)], fill=LIME)

    # Barbell
    rounded(draw, (410, 1215, 1190, 1298), 38, CHAR)
    rounded(draw, (520, 1235, 1080, 1278), 20, CHAR_3)
    rounded(draw, (350, 1135, 430, 1375), 30, CREAM)
    rounded(draw, (1170, 1135, 1250, 1375), 30, CREAM)
    rounded(draw, (405, 1175, 470, 1335), 26, LIME)
    rounded(draw, (1130, 1175, 1195, 1335), 26, LIME)

    star(draw, 280, 260, 24, CREAM)
    star(draw, 1320, 250, 30, LIME)
    return image


def diet() -> Image.Image:
    image = canvas()
    add_glow(image, (100, 120, 1500, 1480))
    draw = ImageDraw.Draw(image)

    # Bowl
    draw.ellipse((260, 250, 1340, 1330), fill=CREAM)
    draw.ellipse((340, 330, 1260, 1250), fill=CHAR_2)
    draw.ellipse((370, 360, 1230, 1220), outline=CHAR_3, width=8)

    # Rice
    draw.ellipse((690, 770, 1120, 1170), fill=CREAM)
    draw.ellipse((740, 820, 1070, 1120), fill=(255, 248, 236, 255))

    # Salmon
    rounded(draw, (500, 500, 780, 690), 42, SALMON)
    for x in range(540, 760, 34):
        line(draw, [(x, 530), (x + 25, 660)], (255, 184, 157, 255), 7)

    # Broccoli
    for cx, cy, r in ((930, 500, 58), (1000, 550, 48), (900, 590, 45), (1040, 460, 38)):
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=GREEN)
        draw.ellipse((cx - r // 2, cy - r // 2, cx + r // 2, cy + r // 2), fill=DARK_GREEN)

    # Egg
    draw.ellipse((610, 760, 880, 980), fill=WHITE)
    draw.ellipse((700, 830, 800, 930), fill=YELLOW)
    draw.ellipse((725, 850, 760, 880), fill=(255, 234, 150, 255))

    # Avocado
    draw.ellipse((930, 760, 1120, 1010), fill=(132, 193, 92, 255))
    draw.ellipse((980, 825, 1070, 940), fill=(212, 197, 110, 255))

    # Tomatoes
    for cx, cy in ((550, 840), (590, 940), (1100, 1090)):
        draw.ellipse((cx - 38, cy - 38, cx + 38, cy + 38), fill=RED)
        draw.ellipse((cx - 15, cy - 42, cx + 15, cy - 20), fill=GREEN)

    # Leaf garnish
    draw.ellipse((780, 540, 870, 640), fill=LIME)
    line(draw, [(825, 560), (820, 620)], LIME_DARK, 8)

    # Fork
    line(draw, [(1390, 380), (1390, 1220)], LIME, 20)
    for x in (1340, 1375, 1410, 1445):
        line(draw, [(x, 300), (x, 470)], LIME, 14)

    star(draw, 250, 320, 26, LIME)
    star(draw, 1350, 1260, 20, CREAM)
    return image


def coach() -> Image.Image:
    image = canvas()
    add_glow(image, (120, 100, 1500, 1500))
    draw = ImageDraw.Draw(image)

    # Energy strokes behind the character
    for start, end, width in (
        ((240, 760), (520, 250), 58),
        ((1320, 820), (1110, 220), 52),
        ((220, 1080), (470, 560), 34),
        ((1370, 1100), (1130, 560), 30),
    ):
        line(draw, [start, end], LIME, width + 16)
        line(draw, [start, end], LIME_DARK, max(10, width - 20))

    # Torso / tank top
    rounded(draw, (330, 690, 1270, 1510), 170, CHAR)
    draw.ellipse((270, 640, 700, 1010), fill=CHAR)
    draw.ellipse((900, 640, 1330, 1010), fill=CHAR)
    rounded(draw, (390, 820, 1210, 1530), 120, CHAR)

    # Neck
    rounded(draw, (705, 535, 895, 760), 55, CREAM)
    draw.ellipse((700, 700, 900, 820), fill=CREAM_DARK)

    # Head
    draw.ellipse((470, 110, 1130, 700), fill=CREAM)
    draw.ellipse((430, 300, 520, 470), fill=CREAM)
    draw.ellipse((1080, 300, 1170, 470), fill=CREAM)

    # Hair
    draw.polygon(
        [
            (490, 360),
            (500, 210),
            (585, 145),
            (640, 250),
            (710, 115),
            (800, 230),
            (875, 105),
            (960, 235),
            (1040, 145),
            (1105, 230),
            (1135, 355),
            (1090, 380),
            (510, 390),
        ],
        fill=CHAR,
    )

    # Eyebrows
    draw.polygon([(590, 355), (760, 390), (750, 430), (590, 405)], fill=CHAR)
    draw.polygon([(840, 390), (1010, 355), (1010, 405), (850, 430)], fill=CHAR)

    # Eyes
    for x in (665, 930):
        draw.ellipse((x, 430, x + 58, 486), fill=CHAR)
        draw.ellipse((x + 14, 440, x + 27, 456), fill=WHITE)

    # Nose
    line(draw, [(790, 465), (775, 545), (815, 555)], CHAR, 9)

    # Mouth
    draw.arc((690, 555, 940, 680), start=12, end=168, fill=CHAR, width=10)

    # Tank top neckline
    draw.polygon([(700, 760), (800, 910), (900, 760)], fill=CREAM_DARK)
    draw.polygon([(730, 775), (800, 875), (870, 775)], fill=CREAM)

    # Crossed arms
    line(draw, [(300, 1080), (880, 930)], CHAR, 142)
    line(draw, [(300, 1080), (880, 930)], CREAM, 122)
    line(draw, [(1300, 1070), (720, 940)], CHAR, 142)
    line(draw, [(1300, 1070), (720, 940)], CREAM, 122)

    # Fists and wristbands
    for cx, cy in ((300, 1080), (1300, 1070)):
        draw.ellipse((cx - 76, cy - 76, cx + 76, cy + 76), fill=CHAR)
        draw.ellipse((cx - 62, cy - 62, cx + 62, cy + 62), fill=CREAM)
    rounded(draw, (370, 1000, 485, 1115), 28, LIME)
    rounded(draw, (1115, 1000, 1230, 1115), 28, LIME)

    # Lightning bolt on chest
    draw.polygon(
        [
            (785, 790),
            (735, 905),
            (790, 905),
            (750, 1025),
            (850, 875),
            (795, 875),
            (835, 790),
        ],
        fill=LIME,
    )

    # Tank top trim
    line(draw, [(470, 760), (560, 900)], LIME, 18)
    line(draw, [(1130, 760), (1040, 900)], LIME, 18)

    star(draw, 260, 360, 28, LIME)
    star(draw, 1330, 430, 22, CREAM)
    return image


def export(name: str, image: Image.Image) -> None:
    folder = ASSETS / f"{name}.imageset"
    folder.mkdir(parents=True, exist_ok=True)
    base = name.lower().replace("theme", "theme-")
    images = []
    for scale, size in (("1x", 320), ("2x", 640), ("3x", 960)):
        filename = f"{base}.png" if scale == "1x" else f"{base}@{scale}.png"
        image.resize((size, size), Image.LANCZOS).save(folder / filename)
        images.append({"filename": filename, "idiom": "universal", "scale": scale})
    (folder / "Contents.json").write_text(
        json.dumps(
            {
                "images": images,
                "info": {"author": "xcode", "version": 1},
                "properties": {"preserves-vector-representation": False},
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print("wrote", folder)


def main() -> None:
    export("ThemeCoach", coach())
    export("ThemeEquipment", equipment())
    export("ThemeTraining", training())
    export("ThemeDiet", diet())


if __name__ == "__main__":
    main()
