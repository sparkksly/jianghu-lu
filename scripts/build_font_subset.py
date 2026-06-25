#!/usr/bin/env python3
"""Subset a CJK font down to only the glyphs the project actually uses.

Scans the game's .gd/.tscn/.tres source for every character that can appear
on screen, then emits a tiny font covering just those. Keeps the web build
small while fixing CJK tofu (browsers have no system-font fallback).

Usage: python build_font_subset.py <source_font.ttf> <output_font.ttf>
Run from the project root.
"""
import os
import sys
import subprocess

EXTRA_PUNCT = "，。！？、：；（）「」『』…—·《》“”‘’￥％"
SKIP_DIRS = ("addons", ".godot", "build", ".git", "test")


def collect_chars() -> set[str]:
    chars: set[str] = set()
    for dirpath, _dirs, files in os.walk("."):
        if any(seg in dirpath for seg in SKIP_DIRS):
            continue
        for f in files:
            if not f.endswith((".gd", ".tscn", ".tres")):
                continue
            try:
                txt = open(os.path.join(dirpath, f), encoding="utf-8").read()
            except OSError:
                continue
            for ch in txt:
                if ord(ch) > 0x2000 or 0x20 <= ord(ch) < 0x7F:
                    chars.add(ch)
    for c in range(0x20, 0x7F):  # full printable ASCII (digits, latin, symbols)
        chars.add(chr(c))
    for ch in EXTRA_PUNCT:
        chars.add(ch)
    return chars


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    src_font, out_font = sys.argv[1], sys.argv[2]
    chars = collect_chars()
    chars_path = os.path.join(os.path.dirname(out_font) or ".", "_subset_chars.txt")
    open(chars_path, "w", encoding="utf-8").write("".join(sorted(chars)))
    subprocess.check_call([
        sys.executable, "-m", "fontTools.subset", src_font,
        "--text-file=" + chars_path,
        "--output-file=" + out_font,
    ])
    os.remove(chars_path)
    print(f"subset {len(chars)} glyphs -> {out_font}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
