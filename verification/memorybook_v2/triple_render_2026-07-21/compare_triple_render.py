#!/usr/bin/env python3
"""Compare deterministic SwiftUI Reader captures with LocalPDFExporter rasters.

This tool intentionally measures output geometry, not design taste. Reader
captures include vertical container padding, so the first step extracts the
actual paper rectangle before mapping both surfaces into paper-point space.
"""

import argparse
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image


PAPER_POINTS = {"letter": (612.0, 792.0), "a4": (595.0, 842.0)}
SOURCE_COLORS = np.array([[209, 224, 194], [31, 74, 61], [199, 79, 43]], dtype=np.float32)
INK = np.array([31, 74, 61], dtype=np.float32)


def extract_reader_page(image: Image.Image, paper: str) -> tuple[Image.Image, tuple[int, int, int, int]]:
    rgb = np.asarray(image.convert("RGB"), dtype=np.int16)
    background = rgb[0, 0]
    different = np.max(np.abs(rgb - background), axis=2) > 4
    active_rows = np.flatnonzero(different.mean(axis=1) > 0.45)
    active_cols = np.flatnonzero(different.mean(axis=0) > 0.45)
    if active_rows.size == 0 or active_cols.size == 0:
        raise RuntimeError("Could not detect Reader paper rectangle")
    x0, y0 = int(active_cols[0]), int(active_rows[0])
    x1, y1 = int(active_cols[-1] + 1), int(active_rows[-1] + 1)
    # XCTest's accessibility screenshot can include a few pixels of the
    # surrounding HStack/TabView.  A4 currently has six such pixels on each
    # horizontal edge.  Comparing that wider rectangle to a PDF would require
    # anisotropic resizing and manufacture several points of apparent glyph
    # drift.  The authored page aspect is known, so take the largest centred
    # rectangle of that aspect from the detected active region.
    target_aspect = PAPER_POINTS[paper][0] / PAPER_POINTS[paper][1]
    width, height = x1 - x0, y1 - y0
    if width / height > target_aspect:
        target_width = int(round(height * target_aspect))
        inset = max(0, (width - target_width) // 2)
        x0 += inset
        x1 = x0 + target_width
    else:
        target_height = int(round(width / target_aspect))
        inset = max(0, (height - target_height) // 2)
        y0 += inset
        y1 = y0 + target_height
    box = (x0, y0, x1, y1)
    return image.crop(box), box


def resize_rgb(image: Image.Image, size: tuple[int, int]) -> np.ndarray:
    return np.asarray(image.convert("RGB").resize(size, Image.Resampling.LANCZOS), dtype=np.float32)


def register_translation(reader: np.ndarray, pdf: np.ndarray, limit: int = 4):
    """Rigidly register the PDF raster to the screenshot's page origin.

    XCUI element screenshots round accessibility coordinates to device pixels,
    so the extracted page origin can be one or two pixels away from the actual
    SwiftUI canvas origin.  This translation removes only that global capture
    origin; it cannot change scale, element geometry, line wrapping or size.
    """
    height, width, _ = reader.shape
    best = None
    for dy in range(-limit, limit + 1):
        for dx in range(-limit, limit + 1):
            rx0, rx1 = max(0, dx), min(width, width + dx)
            ry0, ry1 = max(0, dy), min(height, height + dy)
            px0, px1 = max(0, -dx), min(width, width - dx)
            py0, py1 = max(0, -dy), min(height, height - dy)
            score = float(np.mean(np.abs(reader[ry0:ry1, rx0:rx1] - pdf[py0:py1, px0:px1])))
            if best is None or score < best[0]:
                best = (score, dx, dy)
    _, dx, dy = best
    aligned = np.empty_like(pdf)
    aligned[:] = pdf[0, 0]
    rx0, rx1 = max(0, dx), min(width, width + dx)
    ry0, ry1 = max(0, dy), min(height, height + dy)
    px0, px1 = max(0, -dx), min(width, width - dx)
    py0, py1 = max(0, -dy), min(height, height - dy)
    aligned[ry0:ry1, rx0:rx1] = pdf[py0:py1, px0:px1]
    return aligned, dx, dy


def gradient_edges(rgb: np.ndarray) -> np.ndarray:
    gray = rgb.mean(axis=2)
    dx = np.zeros_like(gray)
    dy = np.zeros_like(gray)
    dx[:, 1:] = np.abs(gray[:, 1:] - gray[:, :-1])
    dy[1:, :] = np.abs(gray[1:, :] - gray[:-1, :])
    return np.maximum(dx, dy) > 24


def dilate(mask: np.ndarray, radius: int) -> np.ndarray:
    result = np.zeros_like(mask)
    height, width = mask.shape
    for dy in range(-radius, radius + 1):
        for dx in range(-radius, radius + 1):
            y0, y1 = max(0, dy), min(height, height + dy)
            x0, x1 = max(0, dx), min(width, width + dx)
            result[y0:y1, x0:x1] |= mask[y0 - dy:y1 - dy, x0 - dx:x1 - dx]
    return result


def mask_bbox(mask: np.ndarray):
    ys, xs = np.nonzero(mask)
    if len(xs) == 0:
        return None
    return (float(xs.min()), float(ys.min()), float(xs.max() + 1), float(ys.max() + 1))


def point_box(pixel_box, width, height, paper):
    if pixel_box is None:
        return None
    pw, ph = PAPER_POINTS[paper]
    x0, y0, x1, y1 = pixel_box
    return [x0 * pw / width, y0 * ph / height, x1 * pw / width, y1 * ph / height]


def box_delta(a, b):
    if a is None or b is None:
        return None
    return max(abs(x - y) for x, y in zip(a, b))


def element_rect(element, plan, paper_name, image_size):
    (x, y), (w, h) = element["normalizedFrame"]
    (paper_x, paper_y), (paper_w, paper_h) = plan["paperRect"]
    page_w, page_h = PAPER_POINTS[paper_name]
    iw, ih = image_size
    return (
        max(0, int((paper_x + (x - 0.015) * paper_w) * iw / page_w)),
        max(0, int((paper_y + (y - 0.015) * paper_h) * ih / page_h)),
        min(iw, int((paper_x + (x + w + 0.015) * paper_w) * iw / page_w)),
        min(ih, int((paper_y + (y + h + 0.015) * paper_h) * ih / page_h)),
    )


def local_color_bbox(rgb, rect, targets, tolerance):
    x0, y0, x1, y1 = rect
    crop = rgb[y0:y1, x0:x1]
    distance = np.linalg.norm(crop[:, :, None, :] - targets[None, None, :, :], axis=3)
    local = mask_bbox(np.min(distance, axis=2) <= tolerance)
    if local is None:
        return None
    lx0, ly0, lx1, ly1 = local
    return (lx0 + x0, ly0 + y0, lx1 + x0, ly1 + y0)


def compare_page(reader_path, pdf_path, manifest_plan, paper):
    reader_source = Image.open(reader_path)
    reader_page, reader_box = extract_reader_page(reader_source, paper)
    pdf_page = Image.open(pdf_path)
    reader_rgb = np.asarray(reader_page.convert("RGB"), dtype=np.float32)
    pdf_rgb = resize_rgb(pdf_page, reader_page.size)
    pdf_rgb, registration_x, registration_y = register_translation(reader_rgb, pdf_rgb)
    mae = float(np.mean(np.abs(reader_rgb - pdf_rgb)))
    rmse = float(math.sqrt(np.mean((reader_rgb - pdf_rgb) ** 2)))

    edge_reader = gradient_edges(reader_rgb)
    edge_pdf = gradient_edges(pdf_rgb)
    point_scale = reader_page.width / PAPER_POINTS[paper][0]
    radius = max(1, int(math.ceil(point_scale)))
    reader_covered = float((edge_reader & dilate(edge_pdf, radius)).sum() / max(1, edge_reader.sum()))
    pdf_covered = float((edge_pdf & dilate(edge_reader, radius)).sum() / max(1, edge_pdf.sum()))

    element_metrics = []
    for element in manifest_plan["orderedElements"]:
        rect = element_rect(element, manifest_plan, paper, reader_page.size)
        if element["kind"] == "image":
            reader_detected = local_color_bbox(reader_rgb, rect, SOURCE_COLORS, 34)
            pdf_detected = local_color_bbox(pdf_rgb, rect, SOURCE_COLORS, 34)
        elif element["kind"] == "text":
            reader_detected = local_color_bbox(reader_rgb, rect, INK[None, :], 30)
            pdf_detected = local_color_bbox(pdf_rgb, rect, INK[None, :], 30)
        else:
            continue
        reader_points = point_box(reader_detected, reader_page.width, reader_page.height, paper)
        pdf_points = point_box(pdf_detected, reader_page.width, reader_page.height, paper)
        element_metrics.append({
            "id": element["id"],
            "kind": element["kind"],
            "zIndex": element["zIndex"],
            "rotationDegrees": element["rotationDegrees"],
            "imageContentMode": element.get("imageContentMode"),
            "readerDetectedBoxPoints": reader_points,
            "pdfDetectedBoxPoints": pdf_points,
            "maxDetectedBoxDeltaPoints": box_delta(reader_points, pdf_points),
        })

    detected_deltas = [e["maxDetectedBoxDeltaPoints"] for e in element_metrics if e["maxDetectedBoxDeltaPoints"] is not None]
    return {
        "readerFile": str(reader_path),
        "pdfRasterFile": str(pdf_path),
        "readerSourcePixels": list(reader_source.size),
        "readerPaperPixels": list(reader_page.size),
        "readerPaperCrop": list(reader_box),
        "pdfRasterPixels": list(pdf_page.size),
        "registrationPixels": [registration_x, registration_y],
        "registrationPoints": [
            registration_x * PAPER_POINTS[paper][0] / reader_page.width,
            registration_y * PAPER_POINTS[paper][1] / reader_page.height,
        ],
        "meanAbsolutePixelDifference": mae,
        "rootMeanSquarePixelDifference": rmse,
        "edgeCoverageWithinOnePoint": {"readerToPDF": reader_covered, "pdfToReader": pdf_covered},
        "maxDetectedElementBoxDeltaPoints": max(detected_deltas) if detected_deltas else None,
        "elements": element_metrics,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--reader-root", type=Path, required=True)
    parser.add_argument("--pdf-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--contact-dir", type=Path)
    args = parser.parse_args()
    result = {"scope": "Warm Paper deterministic Reader versus LocalPDFExporter raster", "papers": {}}
    for paper in ("letter", "a4"):
        manifest = json.loads((args.pdf_root / paper / "manifest.json").read_text())
        pages = []
        contact_rows = []
        for index, plan in enumerate(manifest["plans"], start=1):
            reader_path = args.reader_root / paper / f"reader-page-{index:02d}.png"
            pdf_path = args.pdf_root / paper / f"pdf-raster-{index:02d}.png"
            pages.append(compare_page(
                reader_path,
                pdf_path,
                plan,
                paper,
            ))
            if args.contact_dir:
                reader_page, _ = extract_reader_page(Image.open(reader_path), paper)
                reader_thumb = reader_page.copy(); reader_thumb.thumbnail((240, 340), Image.Resampling.LANCZOS)
                pdf_thumb = Image.open(pdf_path).convert("RGB"); pdf_thumb.thumbnail((240, 340), Image.Resampling.LANCZOS)
                row = Image.new("RGB", (reader_thumb.width + pdf_thumb.width + 8, max(reader_thumb.height, pdf_thumb.height)), "white")
                row.paste(reader_thumb, (0, 0)); row.paste(pdf_thumb, (reader_thumb.width + 8, 0))
                contact_rows.append(row)
        result["papers"][paper] = pages
        if args.contact_dir:
            args.contact_dir.mkdir(parents=True, exist_ok=True)
            sheet = Image.new("RGB", (max(row.width for row in contact_rows), sum(row.height for row in contact_rows) + 6 * (len(contact_rows) - 1)), "white")
            y = 0
            for row in contact_rows:
                sheet.paste(row, (0, y)); y += row.height + 6
            sheet.save(args.contact_dir / f"reader-left_pdf-right-{paper}.jpg", quality=82, optimize=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
