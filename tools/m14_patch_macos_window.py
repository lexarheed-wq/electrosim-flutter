#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path

NEEDLE = "    let windowFrame = self.frame\n"
REPLACEMENT = """    let visibleFrame = NSScreen.main?.visibleFrame ?? self.frame
    let targetWidth = min(visibleFrame.width, max(1180, visibleFrame.width * 0.92))
    let targetHeight = min(visibleFrame.height, max(760, visibleFrame.height * 0.90))
    let windowFrame = NSRect(
      x: visibleFrame.midX - targetWidth / 2,
      y: visibleFrame.midY - targetHeight / 2,
      width: targetWidth,
      height: targetHeight
    )
"""

def patch(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    if REPLACEMENT in text:
        return
    if NEEDLE not in text:
        raise SystemExit(f"M14_WINDOW_PATCH_MARKER_MISSING: {path}")
    text = text.replace(NEEDLE, REPLACEMENT, 1)
    text = text.replace(
        "    self.setFrame(windowFrame, display: true)\n",
        "    self.setFrame(windowFrame, display: true)\n"
        "    self.minSize = NSSize(width: 980, height: 680)\n",
        1,
    )
    path.write_text(text, encoding="utf-8")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: m14_patch_macos_window.py <MainFlutterWindow.swift>")
    patch(Path(sys.argv[1]))
