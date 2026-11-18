#!/usr/bin/env python3
"""Measures what is drawn in zones of a simulator screenshot, in points.

To compare a screen with its Claude Design mockup: take the screenshot with
`xcrun simctl io booted screenshot <file>.png`, then give the zones to
measure, in the screenshot's own pixels:

    python3 -I .claude/tools/measure-screenshot.py shot.png \
        "+ icon=1032,200,1152,310" "Lists text=680,200,815,310"

For each zone it prints the box of the pixels darker than the threshold
(ink on a light background), in pixels and in points, and the dark runs
across its middle row and column — a stroke's thickness, or the gaps of a
glyph. Simulators render at @3x unless `--scale` says otherwise.

Standard library only: the machine has neither PIL nor numpy. Reads 8-bit,
non-interlaced RGB or RGBA PNGs, which is what `simctl` writes.
"""
import argparse
import struct
import zlib


def read_png(path):
    """Width, height, channels, and the unfiltered rows of a PNG."""
    data = open(path, "rb").read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit(f"{path}: not a PNG")
    pos, idat = 8, b""
    width = height = ctype = None
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        kind = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        if kind == b"IHDR":
            width, height, depth, ctype, _, _, interlace = struct.unpack(">IIBBBBB", body)
            if depth != 8 or interlace != 0 or ctype not in (2, 6):
                raise SystemExit(f"{path}: only 8-bit, non-interlaced RGB or RGBA PNGs")
        elif kind == b"IDAT":
            idat += body
        pos += 12 + length
    channels = 4 if ctype == 6 else 3
    raw = zlib.decompress(idat)
    stride = width * channels
    rows, prev, i = [], bytearray(stride), 0
    for _ in range(height):
        kind, line = raw[i], bytearray(raw[i + 1:i + 1 + stride])
        i += 1 + stride
        for x in range(stride):
            a = line[x - channels] if x >= channels else 0
            b = prev[x]
            c = prev[x - channels] if x >= channels else 0
            if kind == 1:
                line[x] = (line[x] + a) & 255
            elif kind == 2:
                line[x] = (line[x] + b) & 255
            elif kind == 3:
                line[x] = (line[x] + (a + b) // 2) & 255
            elif kind == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append(bytes(line))
        prev = line
    return width, height, channels, rows


def is_dark(rows, channels, x, y, threshold):
    row = rows[y]
    return (row[x * channels] + row[x * channels + 1] + row[x * channels + 2]) / 3 < threshold


def dark_box(rows, channels, zone, threshold):
    x0, y0, x1, y1 = zone
    points = [(x, y) for y in range(y0, y1) for x in range(x0, x1) if is_dark(rows, channels, x, y, threshold)]
    if not points:
        return None
    xs, ys = [p[0] for p in points], [p[1] for p in points]
    return min(xs), min(ys), max(xs), max(ys)


def runs(rows, channels, line, threshold):
    """Lengths of the dark runs along a list of (x, y) pixels."""
    found, n = [], 0
    for x, y in line:
        if is_dark(rows, channels, x, y, threshold):
            n += 1
        elif n:
            found.append(n)
            n = 0
    if n:
        found.append(n)
    return found


def parse_zone(text):
    name, _, coords = text.rpartition("=")
    values = [int(v) for v in coords.split(",")]
    if len(values) != 4:
        raise SystemExit(f"zone {text!r}: expected name=x0,y0,x1,y1")
    return name or coords, tuple(values)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("png")
    parser.add_argument("zones", nargs="+", help='"name=x0,y0,x1,y1", in the screenshot\'s pixels')
    parser.add_argument("--threshold", type=int, default=110, help="mean RGB under which a pixel is ink (110)")
    parser.add_argument("--scale", type=int, default=3, help="pixels per point (3)")
    args = parser.parse_args()

    width, height, channels, rows = read_png(args.png)
    print(f"{width}x{height} px = {width / args.scale:.0f}x{height / args.scale:.0f} pt at @{args.scale}x")
    for name, zone in map(parse_zone, args.zones):
        box = dark_box(rows, channels, zone, args.threshold)
        if box is None:
            print(f"{name}: nothing darker than {args.threshold}")
            continue
        bx0, by0, bx1, by1 = box
        w, h = bx1 - bx0 + 1, by1 - by0 + 1
        print(f"{name}: x {bx0}-{bx1}, y {by0}-{by1} -> {w}x{h} px = {w / args.scale:.1f} x {h / args.scale:.1f} pt")
        middle_row = [(x, (by0 + by1) // 2) for x in range(bx0, bx1 + 1)]
        middle_column = [((bx0 + bx1) // 2, y) for y in range(by0, by1 + 1)]
        print(f"  dark runs (px) across the middle row {runs(rows, channels, middle_row, args.threshold)}, "
              f"down the middle column {runs(rows, channels, middle_column, args.threshold)}")


if __name__ == "__main__":
    main()
