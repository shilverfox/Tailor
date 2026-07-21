#!/usr/bin/env python3
"""Verify Warm Paper approved baseline sources against the production contract.

This is a source-level gate for the approved SVG/PNG baseline package. It
checks the contract that must stay aligned with `MemoryBookProductionDefaultFixture`:
paper sizes, page copy, image order, production normalized frames, Fit/Fill
modes, and PNG export presence. Pixel/render diff remains a separate runtime
evidence step.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path("design/reference/v1_1/memory-book/warmPaper")
PAPERS = {
    "letter": {"width": 612.0, "height": 792.0, "paper": (18.0, 18.0, 576.0, 756.0)},
    "a4": {"width": 595.0, "height": 842.0, "paper": (17.5, 17.5, 560.0, 807.0)},
}
PAGES = [
    ("cover", "Milo", "A life in moments", [("photo-fill-rotation-0", (0.08, 0.27, 0.84, 0.40), "slice")]),
    ("dedication", "For Milo", "Made privately from the photographs you chose.", []),
    ("contents", "Contents", "2019-2021", []),
    ("chapterOpener", "Days together", "2019-2021 · A season together", [("photo-fill-rotation-0", (0.08, 0.27, 0.84, 0.40), "slice")]),
    ("photoSelection", "Days together", "Selected moments from 2019-2021.", [
        ("photo-1-fit-rotation-0", (0.08, 0.3546875, 0.41, 0.230625), "meet"),
        ("photo-2-fit-rotation-0", (0.6025, 0.27, 0.225, 0.40), "meet"),
    ]),
    ("milestone", "A year we remember", "A quiet marker from 2017.", [("photo-fill-rotation-0", (0.08, 0.27, 0.84, 0.40), "slice")]),
    ("closing", "Kept with care.", "Tailor never changes your original photos.", []),
]
TITLE_FRAME = (0.08, 0.08, 0.84, 0.10)
SUBTITLE_FRAME = (0.08, 0.17, 0.84, 0.06)


def png_size(path: Path) -> tuple[int, int] | None:
    try:
        data = path.read_bytes()
    except FileNotFoundError:
        return None
    if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return int.from_bytes(data[16:20], "big"), int.from_bytes(data[20:24], "big")


def local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def iter_elements(root: ET.Element, name: str):
    for element in root.iter():
        if local_name(element.tag) == name:
            yield element


def as_float(value: str | None) -> float:
    if value is None:
        raise ValueError("missing numeric attribute")
    return float(value)


def frame_points(paper: tuple[float, float, float, float], normalized: tuple[float, float, float, float]) -> tuple[float, float, float, float]:
    px, py, pw, ph = paper
    x, y, w, h = normalized
    return (px + x * pw, py + y * ph, w * pw, h * ph)


def close(actual: float, expected: float, tolerance: float = 0.03) -> bool:
    return math.isclose(actual, expected, abs_tol=tolerance)


def text_values(svg: ET.Element) -> dict[str, str]:
    values = {}
    for text in iter_elements(svg, "text"):
        element_id = text.attrib.get("id")
        if element_id:
            values[element_id] = "".join(text.itertext())
    return values


def check_svg(paper_name: str, page_name: str, title: str, subtitle: str, image_contracts: list[tuple[str, tuple[float, float, float, float], str]]) -> list[str]:
    errors: list[str] = []
    spec = PAPERS[paper_name]
    svg_path = ROOT / paper_name / f"{page_name}.svg"
    png_path = ROOT / paper_name / f"{page_name}.png"
    if not svg_path.exists():
        return [f"missing svg {svg_path}"]
    try:
        svg = ET.parse(svg_path).getroot()
    except ET.ParseError as exc:
        return [f"invalid svg {svg_path}: {exc}"]

    if not close(as_float(svg.attrib.get("width")), spec["width"]):
        errors.append(f"{paper_name}/{page_name}: svg width mismatch")
    if not close(as_float(svg.attrib.get("height")), spec["height"]):
        errors.append(f"{paper_name}/{page_name}: svg height mismatch")

    expected_png = (int(spec["width"] * 3), int(spec["height"] * 3))
    if png_size(png_path) != expected_png:
        errors.append(f"{paper_name}/{page_name}: png size mismatch, expected {expected_png}, got {png_size(png_path)}")

    texts = text_values(svg)
    if texts.get("title") != title:
        errors.append(f"{paper_name}/{page_name}: title text mismatch")
    if texts.get("subtitle") != subtitle:
        errors.append(f"{paper_name}/{page_name}: subtitle text mismatch")

    title_nodes = [node for node in iter_elements(svg, "text") if node.attrib.get("id") == "title"]
    subtitle_nodes = [node for node in iter_elements(svg, "text") if node.attrib.get("id") == "subtitle"]
    for node, label, normalized in [(title_nodes[0] if title_nodes else None, "title", TITLE_FRAME), (subtitle_nodes[0] if subtitle_nodes else None, "subtitle", SUBTITLE_FRAME)]:
        if node is None:
            errors.append(f"{paper_name}/{page_name}: missing {label} node")
            continue
        expected_x, expected_y, _, _ = frame_points(spec["paper"], normalized)
        if not close(as_float(node.attrib.get("x")), expected_x):
            errors.append(f"{paper_name}/{page_name}: {label} x mismatch")
        # Baseline Y is font baseline, so only enforce frame origin through X
        # and let font metrics remain renderer-owned.

    groups = {node.attrib.get("id"): node for node in iter_elements(svg, "g") if node.attrib.get("id")}
    for image_id, normalized, preserve_suffix in image_contracts:
        group = groups.get(image_id)
        if group is None:
            errors.append(f"{paper_name}/{page_name}: missing image group {image_id}")
            continue
        image_nodes = [node for node in group.iter() if local_name(node.tag) == "image"]
        if len(image_nodes) != 1:
            errors.append(f"{paper_name}/{page_name}: {image_id} image node count mismatch")
            continue
        image = image_nodes[0]
        expected = frame_points(spec["paper"], normalized)
        actual = tuple(as_float(image.attrib.get(key)) for key in ("x", "y", "width", "height"))
        if any(not close(a, e) for a, e in zip(actual, expected)):
            errors.append(f"{paper_name}/{page_name}: {image_id} frame mismatch expected={expected} actual={actual}")
        preserve = image.attrib.get("preserveAspectRatio", "")
        if not preserve.endswith(preserve_suffix):
            errors.append(f"{paper_name}/{page_name}: {image_id} preserveAspectRatio mismatch")
        if "rotation-0" not in image_id:
            errors.append(f"{paper_name}/{page_name}: {image_id} must declare rotation-0")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--json-output", type=Path)
    args = parser.parse_args()

    entries = []
    errors: list[str] = []
    for paper_name in PAPERS:
        for page_name, title, subtitle, image_contracts in PAGES:
            page_errors = check_svg(paper_name, page_name, title, subtitle, image_contracts)
            entries.append({"paper": paper_name, "pageKind": page_name, "errors": page_errors})
            errors.extend(page_errors)

    status = "pass" if not errors else "fail"
    result = {
        "scope": "Warm Paper approved baseline source contract",
        "status": status,
        "checkedCount": len(PAPERS) * len(PAGES),
        "errorCount": len(errors),
        "errors": errors,
        "entries": entries,
    }
    if args.json_output:
        args.json_output.parent.mkdir(parents=True, exist_ok=True)
        args.json_output.write_text(json.dumps(result, indent=2), encoding="utf-8")
    if errors:
        print(f"FAIL: {len(errors)} Warm Paper approved baseline contract issue(s).")
        for error in errors:
            print(error)
        return 1
    print("PASS: Warm Paper approved baseline sources match the production contract.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

