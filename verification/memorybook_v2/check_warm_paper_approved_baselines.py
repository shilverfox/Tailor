#!/usr/bin/env python3
"""Check Warm Paper approved baseline inputs before visual implementation work.

This is intentionally a gate for design-owned files only. It does not compare
runtime screenshots, and it must fail when an approved baseline is missing so
QA cannot accidentally treat candidate or old prototype images as sign-off.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path


PAPERS = ("letter", "a4")
PAGE_KINDS = (
    "cover",
    "dedication",
    "contents",
    "chapterOpener",
    "photoSelection",
    "milestone",
    "closing",
)


def png_size(path: Path) -> tuple[int, int] | None:
    try:
        data = path.read_bytes()
    except OSError:
        return None
    if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return int.from_bytes(data[16:20], "big"), int.from_bytes(data[20:24], "big")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--root",
        type=Path,
        default=Path("design/reference/v1_1/memory-book/warmPaper"),
        help="Warm Paper approved baseline root.",
    )
    parser.add_argument(
        "--json-output",
        type=Path,
        help="Optional path for a machine-readable check result.",
    )
    args = parser.parse_args()

    entries = []
    missing = []
    invalid_png = []
    for paper in PAPERS:
        for page_kind in PAGE_KINDS:
            path = args.root / paper / f"{page_kind}.png"
            exists = path.is_file()
            size = png_size(path) if exists else None
            if not exists:
                missing.append(str(path))
            elif size is None:
                invalid_png.append(str(path))
            entries.append({
                "paper": paper,
                "pageKind": page_kind,
                "path": str(path),
                "exists": exists,
                "pngSize": list(size) if size else None,
            })

    result = {
        "scope": "Warm Paper approved baseline preflight",
        "requiredCount": len(PAPERS) * len(PAGE_KINDS),
        "presentCount": sum(1 for entry in entries if entry["exists"]),
        "missing": missing,
        "invalidPng": invalid_png,
        "entries": entries,
        "status": "pass" if not missing and not invalid_png else "blocked-design-baseline",
    }

    if args.json_output:
        args.json_output.parent.mkdir(parents=True, exist_ok=True)
        args.json_output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    if result["status"] != "pass":
        print(f"BLOCKED: {len(missing)} missing approved baseline PNG(s), {len(invalid_png)} invalid PNG(s).")
        for path in missing:
            print(f"MISSING {path}")
        for path in invalid_png:
            print(f"INVALID_PNG {path}")
        return 1

    print("PASS: all Warm Paper approved baseline PNGs are present.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
