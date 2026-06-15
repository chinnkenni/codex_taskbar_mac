#!/usr/bin/env python3
from collections import deque
from pathlib import Path
import sys

from PIL import Image


def remove_connected_dark_background(image: Image.Image, threshold: int = 18) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    seen = bytearray(width * height)
    queue = deque()

    def index(x: int, y: int) -> int:
        return y * width + x

    def is_background(x: int, y: int) -> bool:
        r, g, b, _ = pixels[x, y]
        return r <= threshold and g <= threshold and b <= threshold

    for x in range(width):
        for y in (0, height - 1):
            if is_background(x, y):
                queue.append((x, y))
                seen[index(x, y)] = 1

    for y in range(height):
        for x in (0, width - 1):
            if not seen[index(x, y)] and is_background(x, y):
                queue.append((x, y))
                seen[index(x, y)] = 1

    while queue:
        x, y = queue.popleft()
        r, g, b, _ = pixels[x, y]
        pixels[x, y] = (r, g, b, 0)

        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if nx < 0 or ny < 0 or nx >= width or ny >= height:
                continue
            offset = index(nx, ny)
            if seen[offset] or not is_background(nx, ny):
                continue
            seen[offset] = 1
            queue.append((nx, ny))

    return rgba


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: prepare-icon.py <input-image> <output-png>", file=sys.stderr)
        return 2

    input_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])
    image = Image.open(input_path).resize((1024, 1024), Image.Resampling.LANCZOS)
    image = remove_connected_dark_background(image)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    image.save(output_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
