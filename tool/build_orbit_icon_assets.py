"""Derive the launcher-icon assets from the one piece of orbit artwork.

WHY THIS EXISTS
---------------
`branding/icon_fg_orbit.png` is the adaptive icon's *foreground* layer:
Android composites it over `adaptive_icon_background` (`#0B182B`, set in
`pubspec.yaml`), so everything that is not the emblem must be **transparent**.

The version shipped in 1.1.0 was not. Its alpha channel was a hard-edged
bucket shape — the trace of an automatic background removal that flood-filled
inwards from the edges and stopped where the emblem's halo began. The pixels
inside that shape kept the artwork's own pale-blue sky, which is not `#0B182B`,
so every launcher drew a light rectangle with notched corners behind the
emblem, plus a strip of chopped-up wordmark along the bottom. Seen on the
Infinix on 2026-09-04, at the size a user actually sees it.

`app_icon_orbit.png` — the square legacy icon — has its own version of the
second half of that problem: it is a crop of a taller lockup, so the top of the
"AL NUJOOM REAL ESTATE" wordmark is sliced off along its bottom edge. At 48 dp
that reads as dirt.

Both are re-derived here from the same source, so the derivation is written
down rather than living in whatever tool produced the originals once.

WHAT IT DOES
------------
1. Finds the emblem by its brightness — it and its halo are the only bright
   thing on the artwork — ignoring the bottom tenth where the cropped wordmark
   sits.
2. Cuts a circular alpha around it with a wide feather, so the halo dissolves
   into the navy instead of ending at an edge.
3. Scales the result into the adaptive icon's safe zone. Android guarantees
   only the central 72 of 108 dp is visible — two thirds — and clips the rest
   to whatever mask the launcher uses, so anything wider can lose the orbit
   ring on a round-mask device.
4. Writes three files, because the three places the emblem appears mask it
   differently: the adaptive foreground (flutter_launcher_icons insets it by
   16% itself), the Android-12+ splash icon (the OS shows the central two
   thirds), and a legacy square that is the same emblem on the same navy with
   no cropped text.

RUN
---
    python tool/build_orbit_icon_assets.py
    dart run flutter_launcher_icons
    dart run flutter_native_splash:create

The source artwork is `branding/app_icon_orbit.png` and is never
modified. Re-running is idempotent.
"""

from __future__ import annotations

import sys
from pathlib import Path

try:
    import numpy as np
    from PIL import Image, ImageFilter
except ImportError as exc:  # pragma: no cover - developer tooling
    sys.exit(f"needs Pillow and numpy: {exc}")

ROOT = Path(__file__).resolve().parent.parent
# Source art, not shipped: a declared Flutter asset directory bundles every
# file in it, and none of these is loaded at runtime.
BRANDING = ROOT / "branding"

SOURCE = BRANDING / "app_icon_orbit.png"
SPLASH_SOURCE = BRANDING / "splash_orbit_source.png"
SPLASH = BRANDING / "splash_orbit.png"
FOREGROUND = BRANDING / "icon_fg_orbit.png"
SPLASH_ICON = BRANDING / "splash_icon_orbit.png"
LEGACY = BRANDING / "app_icon_orbit_square.png"

NAVY = (0x0B, 0x18, 0x2B, 255)

# Android's adaptive icon is a 108 dp canvas of which only the central 72 dp —
# two thirds — is guaranteed visible. That inset is NOT ours to apply:
# flutter_launcher_icons wraps the foreground in `<inset android:inset="16%">`
# (see the generated mipmap-anydpi-v26/launcher_icon.xml), leaving the drawable
# 68% of the canvas, which is the safe zone. So the foreground it is handed
# should be close to full-bleed; 0.90 puts the emblem at 0.90 x 0.68 = 61% of
# the finished icon, which is where a mark normally sits.
#
# Applying the two-thirds rule here as well was the second bug in the 1.1.0
# asset: 0.66 x 0.68 left the emblem at 45% of the icon, a small mark adrift in
# a large square. It only looked full because the slab of sky behind it did the
# filling.
FOREGROUND_FILL = 0.90

# The Android-12+ splash is masked differently — the OS shows the central two
# thirds of the icon canvas and clips the rest — and flutter_native_splash
# passes the image through untouched. So that one really does want 2/3.
SPLASH_ICON_FILL = 72 / 108

# The legacy icon is not masked to a safe zone, but launchers do round it.
LEGACY_FILL = 0.82

# The pre-Android-12 splash is a full-bleed portrait image. Its 1.1.0 version
# had the same slab: emblem and wordmark sat on a lighter rectangle whose four
# edges were plainly visible against the navy on every cold start. It is
# rebuilt here rather than keyed, because the slab's own upper gradient is as
# bright as parts of the emblem and no threshold separates them. The wordmark
# is lifted out on its own — type is far brighter than anything behind it — and
# set back at the coordinates it already occupied, so the composition does not
# move.
SPLASH_SIZE = (1080, 1920)
SPLASH_EMBLEM_CENTRE = (540, 801)
SPLASH_EMBLEM_CORE = 334          # px across, measured from the 1.1.0 splash
WORDMARK_BAND = (1000, 1100)      # y range holding "ALNUJOM REAL ESTATE"
WORDMARK_KEY = (90, 150)          # luminance ramp that keeps type, drops plate
CORE_LUMINANCE = 170              # "this pixel is emblem, not halo"

# Alpha is 1 inside FEATHER_IN of the emblem radius and 0 beyond FEATHER_OUT.
FEATHER_IN = 0.90
FEATHER_OUT = 1.06
FEATHER_BLUR = 10

BRIGHT = 150          # luminance above which a pixel is emblem, not sky
IGNORE_BOTTOM = 0.10  # fraction of the artwork holding the cropped wordmark


def save(img: Image.Image, path: Path) -> int:
    """Write a PNG quantised to 256 colours.

    These are launcher and splash art: a navy field, a silver emblem and one
    line of type. Full-colour PNGs of them cost about a megabyte of APK
    between them — the artwork's starfield is noise, and noise is what PNG
    cannot compress — while at the size a phone actually draws them 256
    colours is indistinguishable. Checked side by side at 4x before choosing
    this. Dithering is off: it would put back the noise this removes.
    """
    img.quantize(colors=256, dither=Image.NONE).save(path, optimize=True)
    return path.stat().st_size


def emblem_bounds(art: Image.Image) -> tuple[float, float, float]:
    """Return (centre_x, centre_y, radius) of the emblem in pixels."""
    w, h = art.size
    lum = np.asarray(art.convert("L"), dtype=np.float32)
    lit = lum[: int(h * (1 - IGNORE_BOTTOM)), :] > BRIGHT
    ys, xs = np.nonzero(lit)
    if xs.size == 0:
        raise SystemExit(f"no bright region found in {SOURCE} — is it the right art?")
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
    radius = max(x1 - x0, y1 - y0) / 2.0
    print(f"  emblem: centre ({cx:.0f}, {cy:.0f})  radius {radius:.0f}px "
          f"= {2 * radius / w:.0%} of the canvas")
    return cx, cy, radius


def cut_out(art: Image.Image, cx: float, cy: float, radius: float) -> Image.Image:
    """Feather a circular alpha around the emblem."""
    w, h = art.size
    yy, xx = np.mgrid[0:h, 0:w]
    r = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / radius
    a = np.clip((FEATHER_OUT - r) / (FEATHER_OUT - FEATHER_IN), 0, 1)
    alpha = Image.fromarray((a * 255).astype("uint8")).filter(
        ImageFilter.GaussianBlur(FEATHER_BLUR)
    )
    out = art.convert("RGBA")
    out.putalpha(alpha)
    return out


def place(cut: Image.Image, source_fraction: float, target_fraction: float,
          background: tuple[int, int, int, int] | None) -> Image.Image:
    """Rescale so the emblem takes `target_fraction` of a same-sized canvas."""
    w, h = cut.size
    scale = target_fraction / source_fraction
    side = max(1, int(round(w * scale)))
    scaled = cut.resize((side, side), Image.LANCZOS)
    canvas = Image.new("RGBA", (w, h), background or (0, 0, 0, 0))
    canvas.paste(scaled, ((w - side) // 2, (h - side) // 2), scaled)
    return canvas


def build_splash(cut: Image.Image, core_width: float) -> Image.Image:
    """Recompose the portrait splash: navy, clean emblem, keyed wordmark."""
    if not SPLASH_SOURCE.exists():
        return None
    src = Image.open(SPLASH_SOURCE).convert("RGB")
    w, h = src.size
    lum = np.asarray(src, dtype=np.float32).mean(axis=2)

    top, bottom = WORDMARK_BAND
    band = src.crop((0, top, w, bottom)).convert("RGBA")
    lo, hi = WORDMARK_KEY
    band_alpha = np.clip((lum[top:bottom, :] - lo) / (hi - lo), 0, 1)
    band.putalpha(
        Image.fromarray((band_alpha * 255).astype("uint8")).filter(
            ImageFilter.GaussianBlur(0.8)
        )
    )

    scale = SPLASH_EMBLEM_CORE / core_width
    side = max(1, int(round(cut.size[0] * scale)))
    emblem = cut.resize((side, side), Image.LANCZOS)

    out = Image.new("RGBA", (w, h), NAVY)
    ecx, ecy = SPLASH_EMBLEM_CENTRE
    out.alpha_composite(emblem, (int(ecx - side / 2), int(ecy - side / 2)))
    out.alpha_composite(band, (0, top))
    return out.convert("RGB")


def main() -> None:
    if not SOURCE.exists():
        raise SystemExit(f"missing source artwork: {SOURCE}")

    art = Image.open(SOURCE).convert("RGB")
    print(f"source: {SOURCE.relative_to(ROOT)} {art.size[0]}x{art.size[1]}")
    cx, cy, radius = emblem_bounds(art)
    fraction = 2 * radius / art.size[0]

    cut = cut_out(art, cx, cy, radius)

    fg = place(cut, fraction, FOREGROUND_FILL, None)
    size = save(fg, FOREGROUND)
    print(f"wrote {FOREGROUND.relative_to(ROOT)} — emblem {FOREGROUND_FILL:.0%} of "
          f"canvas ({FOREGROUND_FILL * 0.68:.0%} once inset), {size // 1024} KB")

    splash_icon = place(cut, fraction, SPLASH_ICON_FILL, None)
    save(splash_icon, SPLASH_ICON)
    print(f"wrote {SPLASH_ICON.relative_to(ROOT)} "
          f"— emblem {SPLASH_ICON_FILL:.0%} of canvas, for the Android-12 splash")

    square = place(cut, fraction, LEGACY_FILL, NAVY).convert("RGB")
    save(square, LEGACY)
    print(f"wrote {LEGACY.relative_to(ROOT)} — emblem {LEGACY_FILL:.0%} on #0B182B")

    lum = np.asarray(art.convert("L"), dtype=np.float32)
    lit = lum[: int(art.size[1] * (1 - IGNORE_BOTTOM)), :] > CORE_LUMINANCE
    core_xs = np.nonzero(lit.any(axis=0))[0]
    splash = build_splash(cut, float(core_xs.max() - core_xs.min()))
    if splash is None:
        print(f"skipped {SPLASH.relative_to(ROOT)} — no {SPLASH_SOURCE.name} to rebuild from")
    else:
        save(splash, SPLASH)
        print(f"wrote {SPLASH.relative_to(ROOT)} — emblem + wordmark on #0B182B, no slab")

    print("\nnow run:  dart run flutter_launcher_icons"
          "  &&  dart run flutter_native_splash:create")


if __name__ == "__main__":
    main()
