"""Builds every install icon in web/icons from app_icons/app_icon_master.png.

Run from the project root after replacing the master:  python tool/make_icons.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
MASTER = ROOT / "app_icons" / "app_icon_master.png"
OUT = ROOT / "web" / "icons"
BACKGROUND = (254, 204, 19)  # the master's edge yellow, so padding blends in

# Android crops maskable icons to any shape inside the centre 80% circle; the robot reaches 77% of the master's radius.
MASKABLE_SCALE = 0.90
# Desktop installs show the icon as drawn, so it gets its own rounded corners.
CORNER_RATIO = 0.22


def rounded(image: Image.Image) -> Image.Image:
    size = image.width * 4
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1), radius=int(size * CORNER_RATIO), fill=255)
    out = image.convert("RGBA")
    out.putalpha(mask.resize(image.size, Image.LANCZOS))
    return out


def maskable(master: Image.Image) -> Image.Image:
    canvas = Image.new("RGB", master.size, BACKGROUND)
    inner = int(master.width * MASKABLE_SCALE)
    offset = (master.width - inner) // 2
    canvas.paste(master.resize((inner, inner), Image.LANCZOS), (offset, offset))
    return canvas


def save(image: Image.Image, size: int, name: str) -> None:
    image.resize((size, size), Image.LANCZOS).save(OUT / name, optimize=True)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    master = Image.open(MASTER).convert("RGB")
    corner = rounded(master)
    padded = maskable(master)

    for size in (96, 144, 192, 256, 384, 512):
        save(corner, size, f"Icon-{size}.png")
    for size in (192, 512):
        save(padded, size, f"Icon-maskable-{size}.png")
    # iOS rounds the corners itself and turns transparency black.
    save(master, 180, "apple-touch-icon.png")

    save(corner, 32, "favicon-32.png")
    save(corner, 16, "favicon-16.png")
    corner.save(ROOT / "web" / "favicon.ico", sizes=[(16, 16), (32, 32), (48, 48), (64, 64)])


if __name__ == "__main__":
    main()
