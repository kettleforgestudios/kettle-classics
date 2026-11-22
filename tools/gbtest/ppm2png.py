#!/usr/bin/env python3
"""Convert a P6 .ppm screenshot to .png (standard library only), optionally scaled up.

Usage: ppm2png.py in.ppm out.png [scale]
"""
import struct
import sys
import zlib


def main() -> None:
    src, dst = sys.argv[1], sys.argv[2]
    scale = int(sys.argv[3]) if len(sys.argv) > 3 else 1
    data = open(src, "rb").read()
    parts = data.split(b"\n", 3)
    width, height = map(int, parts[1].split())
    pixels = parts[3]
    rows = []
    for y in range(height):
        row = pixels[y * width * 3:(y + 1) * width * 3]
        wide = b"".join(row[x * 3:x * 3 + 3] * scale for x in range(width))
        rows.extend([b"\x00" + wide] * scale)

    def chunk(kind: bytes, body: bytes) -> bytes:
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width * scale, height * scale, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(b"".join(rows), 9))
    png += chunk(b"IEND", b"")
    open(dst, "wb").write(png)


if __name__ == "__main__":
    main()
