#!/usr/bin/env python3
import struct
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) < 4 or len(sys.argv[2:]) % 2 != 0:
        print("Usage: make-icns.py <output.icns> <type> <png> [<type> <png> ...]", file=sys.stderr)
        return 2

    output = Path(sys.argv[1])
    pairs = list(zip(sys.argv[2::2], sys.argv[3::2]))
    chunks = []

    for type_code, png_path in pairs:
        if len(type_code.encode("ascii")) != 4:
            print(f"Invalid icon type: {type_code}", file=sys.stderr)
            return 2
        data = Path(png_path).read_bytes()
        chunks.append(type_code.encode("ascii") + struct.pack(">I", len(data) + 8) + data)

    payload = b"".join(chunks)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(b"icns" + struct.pack(">I", len(payload) + 8) + payload)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
