#!/usr/bin/env python3
"""
Scan a folder, identify Instagram screenshots, and crop only the post image area.

Usage:
    python instagram_crop.py <input_folder> [output_folder]

Output defaults to <input_folder>/cropped/
Supports light and dark theme screenshots.
"""

from __future__ import annotations

import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


# ── Instagram aspect ratios (height / width) ─────────────────────────────────
_INSTAGRAM_RATIOS = [
    1.0,          # Square  (1:1)
    1.25,         # Portrait (4:5)
    1.0 / 1.91,  # Landscape (1.91:1)
]


# Width the pixel-valued constants below were tuned against (iPhone @3x).
_REFERENCE_WIDTH = 1290


def _scale(width: int) -> float:
    """Factor mapping a reference-width constant onto this screenshot."""
    return width / _REFERENCE_WIDTH


def _px(value: float, s: float, *, odd: bool = False) -> int:
    """Scale a reference-width pixel constant, keeping it usable as a size."""
    v = max(1, int(round(value * s)))
    if odd and v % 2 == 0:
        v += 1
    return v


# ── Per-row statistics ────────────────────────────────────────────────────────

def _row_mean_std(img: Image.Image) -> tuple[np.ndarray, np.ndarray]:
    arr = np.array(img.convert("L"), dtype=np.float32)
    return arr.mean(axis=1), arr.std(axis=1)


# ── Detection ─────────────────────────────────────────────────────────────────

def is_instagram_screenshot(img: Image.Image) -> bool:
    """
    Heuristics:
      1. Portrait phone aspect ratio  (1.6 – 2.5)
      2. Top 12% is uniformly light (light theme) or dark (dark theme)
      3. Bottom 10% follows the same pattern (navigation bar)
    """
    w, h = img.size

    # Must be portrait
    if w >= h:
        return False
    ratio = h / w
    if not (1.6 <= ratio <= 2.5):
        return False

    row_mean, row_std = _row_mean_std(img)
    n = len(row_mean)

    # Evaluate header and footer brightness
    header_mean = float(row_mean[: int(n * 0.12)].mean())

    # For the footer, use the 10th-percentile row mean alongside the overall
    # mean.  When a next-post preview or caption sits inside the bottom 10%,
    # the mean is pulled into the ambiguous 80-180 range even though the nav
    # bar rows are clearly dark (<80).  min() surfaces that dark nav bar.
    footer_rows = row_mean[int(n * 0.90) :]
    footer_mean = min(float(footer_rows.mean()), float(np.percentile(footer_rows, 10)))

    # Light theme: both regions > 180.  Dark theme: both < 80.
    # Mid-grey (80–180) is ambiguous → not Instagram
    def is_ui_color(v: float) -> bool:
        return v > 180 or v < 80

    return is_ui_color(header_mean) and is_ui_color(footer_mean)


# ── Crop bounds detection ─────────────────────────────────────────────────────

def _find_post_bounds(img: Image.Image) -> tuple[int, int]:
    """Return (top_y, bottom_y) of the post image inside the screenshot."""
    w, h = img.size
    row_mean, row_std = _row_mean_std(img)
    n = len(row_mean)

    # Detect theme
    header_mean = row_mean[: int(n * 0.12)].mean()
    dark = header_mean < 80

    # UI rows: uniform color matching the theme
    if dark:
        is_ui = (row_mean < 50) & (row_std < 25)
    else:
        is_ui = (row_mean > 215) & (row_std < 25)

    is_content = ~is_ui

    # Search zone: skip extreme top/bottom to avoid status bar and nav bar
    zone_top = int(n * 0.10)
    zone_bot = int(n * 0.85)
    content_zone = is_content[zone_top:zone_bot]

    # Collect continuous content blocks inside the zone
    blocks: list[tuple[int, int]] = []
    in_block = False
    bstart = 0
    for i, val in enumerate(content_zone):
        if val and not in_block:
            in_block = True
            bstart = i
        elif not val and in_block:
            in_block = False
            blocks.append((zone_top + bstart, zone_top + i))
    if in_block:
        blocks.append((zone_top + bstart, zone_top + len(content_zone)))

    if not blocks:
        # Fallback: fixed estimate
        top = int(n * 0.20)
        return top, min(top + w, h)

    # Largest block = post image
    detected_top, detected_bot = max(blocks, key=lambda b: b[1] - b[0])

    # Snap to the nearest valid Instagram aspect ratio
    detected_h = detected_bot - detected_top
    target_heights = [int(w * r) for r in _INSTAGRAM_RATIOS]
    best_h = min(target_heights, key=lambda th: abs(th - detected_h))

    return detected_top, min(detected_top + best_h, h)


# ── Pagination indicator removal ──────────────────────────────────────────────

def _detect_indicator_mask(arr: np.ndarray, expand_px: int = 50) -> np.ndarray | None:
    """
    Locate the 'N/M' pagination badge in the top-right of the post image.
    Returns a binary inpainting mask, or None if no badge is found.

    Strategy:
      The badge has WHITE text on a semi-transparent dark pill background.
      1. Find pixels that are BRIGHT (>210, badge text) AND whose local
         35x35 neighborhood mean is DARK (<160).  This singles out "white
         text on dark badge background" vs white walls/rope with a bright
         local neighbourhood.
      2. Dilate to merge adjacent glyphs into one blob.
      3. Keep only blobs whose vertical placement and height match the
         badge.  Instagram pins the badge a fixed distance below the top of
         the post image and renders it at a fixed font size, so both scale
         with the screenshot width.  Photo content that happens to be white
         on dark (rope, tassels, highlights) lands at other offsets and is
         rejected by this alone.
      4. Among the survivors take the largest by area.
    """
    h, w = arr.shape[:2]
    s = _scale(w)
    expand_px = _px(expand_px, s)

    # Search zone: top 13 %, right 30 %
    zy = max(1, int(h * 0.13))
    zx = max(0, int(w * 0.70))
    zone = arr[:zy, zx:]
    zh, zw = zone.shape[:2]

    gray = cv2.cvtColor(zone, cv2.COLOR_RGB2GRAY).astype(np.float32)

    # Local neighbourhood mean — dark here means badge background, not open photo
    blur_k = _px(35, s)
    local_mean = cv2.blur(gray, (blur_k, blur_k))

    # White text sitting on a dark badge background
    text_mask = ((gray > 210) & (local_mean < 160)).astype(np.uint8) * 255

    # Dilate to connect adjacent glyphs into a single blob
    dil_k = _px(15, s)
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (dil_k, dil_k))
    dilated = cv2.dilate(text_mask, kernel)

    num_labels, _, stats, _ = cv2.connectedComponentsWithStats(dilated)
    if num_labels < 2:
        return None

    # Badge geometry, expressed relative to the screenshot width so the same
    # numbers hold for any device scale.  Measured consistently across
    # samples: the dilated text block starts ~4.7 % of the width below the
    # top of the post and stands ~3.6 % of the width tall.
    top_lo,  top_hi  = 0.030 * w, 0.070 * w
    high_lo, high_hi = 0.030 * w, 0.048 * w

    best = None
    for i in range(1, num_labels):
        cx  = int(stats[i, cv2.CC_STAT_LEFT])
        cy  = int(stats[i, cv2.CC_STAT_TOP])
        cw  = int(stats[i, cv2.CC_STAT_WIDTH])
        ch  = int(stats[i, cv2.CC_STAT_HEIGHT])
        a   = int(stats[i, cv2.CC_STAT_AREA])
        right = cx + cw

        if cw < ch:                          continue  # badge reads horizontal
        if a < 500 * s * s:                  continue  # not a tiny speck
        if right < zw * 0.55:                continue  # must be in right half
        if right >= zw - _px(5, s):          continue  # at edge = photo content
        if not (top_lo  <= cy <= top_hi):    continue  # wrong vertical offset
        if not (high_lo <= ch <= high_hi):   continue  # wrong text size

        if best is None or a > best[4]:
            best = [cx, cy, right, cy + ch, a]

    if best is None:
        return None

    bx1, by1, bx2, by2, _ = best

    fy1 = max(0, by1 - expand_px)
    fy2 = min(h, by2 + expand_px)
    fx1 = max(0, zx + bx1 - expand_px)
    fx2 = min(w, zx + bx2 + expand_px)

    mask = np.zeros((h, w), dtype=np.uint8)
    mask[fy1:fy2, fx1:fx2] = 255
    return mask


def _remove_indicator(img: Image.Image) -> Image.Image:
    """Detect the pagination badge and inpaint it away."""
    arr  = np.array(img)
    mask = _detect_indicator_mask(arr)
    if mask is None:
        return img

    bgr    = cv2.cvtColor(arr, cv2.COLOR_RGB2BGR)
    result = cv2.inpaint(bgr, mask, inpaintRadius=_px(25, _scale(arr.shape[1])),
                         flags=cv2.INPAINT_TELEA)
    return Image.fromarray(cv2.cvtColor(result, cv2.COLOR_BGR2RGB))


# ── Corner overlay icon removal ───────────────────────────────────────────────

def _remove_corner_icons(img: Image.Image) -> Image.Image:
    """
    Detect and inpaint small circular UI icons in the bottom corners of the
    cropped post image (mute button, person/follow icon, etc.).

    Strategy:
      Search only the bottom 12% of height near each side edge.  Use Hough
      circles to find circular blobs, then validate by checking the interior
      mean (medium grey = overlay, not photo content) and std (icon has
      internal detail, pure walls/floors do not).
    """
    arr = np.array(img)
    h, w = arr.shape[:2]
    s = _scale(w)
    gray = cv2.cvtColor(arr, cv2.COLOR_RGB2GRAY)

    ZONE_H = int(h * 0.12)
    ZONE_W = _px(140, s)
    min_r = _px(34, s)
    max_r = _px(48, s)

    # Instagram anchors these buttons at a fixed inset from the corner.
    # Anything closer to (or further from) the edge is photo content.
    inset_x = (0.040 * w, 0.085 * w)
    inset_y = (0.035 * h, 0.075 * h)

    corners = [
        (h - ZONE_H, h, 0,         ZONE_W, "BL"),
        (h - ZONE_H, h, w - ZONE_W, w,     "BR"),
    ]

    mask = np.zeros((h, w), dtype=np.uint8)
    found = False

    for zy0, zy1, zx0, zx1, _ in corners:
        zone = gray[zy0:zy1, zx0:zx1]
        circles = cv2.HoughCircles(
            zone, cv2.HOUGH_GRADIENT, dp=1, minDist=_px(40, s),
            param1=40, param2=15,
            minRadius=min_r, maxRadius=max_r,
        )
        if circles is None:
            continue

        for (cx, cy, r) in circles[0]:
            cx, cy, r = int(cx), int(cy), int(r)
            abs_x, abs_y = zx0 + cx, zy0 + cy

            # Must sit at the expected inset from the nearest corner
            dx = abs_x if zx0 == 0 else w - abs_x
            dy = h - abs_y
            if not (inset_x[0] <= dx <= inset_x[1]):
                continue
            if not (inset_y[0] <= dy <= inset_y[1]):
                continue

            y0p = max(0, abs_y - r);  y1p = min(h, abs_y + r + 1)
            x0p = max(0, abs_x - r);  x1p = min(w, abs_x + r + 1)
            patch = gray[y0p:y1p, x0p:x1p]
            cm = np.zeros_like(patch)
            cv2.circle(cm, (abs_x - x0p, abs_y - y0p), r, 1, -1)
            pixels = patch[cm == 1]
            if len(pixels) < 80 * s * s:
                continue

            mean_ = float(pixels.mean())
            std_  = float(pixels.std())
            # Semi-transparent grey icon: medium brightness, has internal detail
            if not (70 < mean_ < 160 and std_ > 28):
                continue

            cv2.circle(mask, (abs_x, abs_y), r + _px(14, s), 255, -1)
            found = True

    if not found:
        return img

    bgr    = cv2.cvtColor(arr, cv2.COLOR_RGB2BGR)
    result = cv2.inpaint(bgr, mask, inpaintRadius=_px(22, s), flags=cv2.INPAINT_TELEA)
    return Image.fromarray(cv2.cvtColor(result, cv2.COLOR_BGR2RGB))


# ── Crop + save ───────────────────────────────────────────────────────────────

def crop_post_image(img_path: Path, output_dir: Path) -> bool:
    try:
        img = Image.open(img_path).convert("RGB")
        w, h = img.size

        top, bottom = _find_post_bounds(img)
        if bottom <= top:
            print(f"  Could not determine post bounds for {img_path.name}")
            return False

        cropped = img.crop((0, top, w, bottom))
        cropped = _remove_indicator(cropped)
        cropped = _remove_corner_icons(cropped)

        out_name = f"{img_path.stem}_cropped{img_path.suffix}"
        out_path = output_dir / out_name
        cropped.save(out_path)
        print(f"  Saved  : {out_name}  ({w}x{bottom - top}px, y={top}–{bottom})")
        return True

    except Exception as exc:
        print(f"  Error  : {exc}")
        return False


# ── Main ──────────────────────────────────────────────────────────────────────

def process_folder(input_folder: str, output_folder: str | None = None) -> None:
    input_path = Path(input_folder)
    if not input_path.is_dir():
        print(f"Error: '{input_folder}' is not a valid directory.")
        sys.exit(1)

    out_path = Path(output_folder) if output_folder else input_path / "cropped"
    out_path.mkdir(parents=True, exist_ok=True)

    exts = {".jpg", ".jpeg", ".png", ".webp"}
    images = sorted(
        f for f in input_path.iterdir()
        if f.is_file() and f.suffix.lower() in exts
    )

    if not images:
        print("No images found.")
        return

    print(f"Scanning {len(images)} image(s) in '{input_path.name}/'...\n")

    ig_count = cropped_count = 0
    for img_path in images:
        print(f"[{img_path.name}]")
        try:
            img = Image.open(img_path)
        except Exception as exc:
            print(f"  Cannot open: {exc}")
            continue

        if is_instagram_screenshot(img):
            print("  -> Instagram screenshot detected")
            ig_count += 1
            if crop_post_image(img_path, out_path):
                cropped_count += 1
        else:
            print("  -> Not an Instagram screenshot, skipped")

    print(
        f"\nDone: {ig_count} Instagram screenshot(s) found, "
        f"{cropped_count} image(s) cropped."
    )
    print(f"Output: {out_path}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python instagram_crop.py <input_folder> [output_folder]")
        sys.exit(1)

    process_folder(
        sys.argv[1],
        sys.argv[2] if len(sys.argv) > 2 else None,
    )
