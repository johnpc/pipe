# App icon

The icon is generated with Gemini's image model (the `/nano-banana` skill),
not drawn by hand. `generate_icon.py` holds the prompts; the chosen concept is
**"pipe opening + play"**: a section of coral pipe with a glowing teal play
triangle in its opening and teal sound ripples, in the README banner's palette.
The dark variant is generated from the light one so the mark is identical; the
tinted variant (iOS 18 tinted home screens) is the dark render desaturated.

Regenerate (needs `GEMINI_API_KEY` and the `google-genai` package):

```bash
python3 scripts/icon/generate_icon.py                       # writes g-*.png into the cwd
# square-crop, flatten to opaque sRGB, and install:
A=pipe/Assets.xcassets/AppIcon.appiconset
magick g-pipeplay-light.png -alpha off -colorspace sRGB -strip $A/icon-1024.png
magick g-pipeplay-dark.png  -alpha off -colorspace sRGB -strip $A/icon-1024-dark.png
magick g-pipeplay-dark.png  -colorspace gray -alpha off -strip $A/icon-1024-tinted.png
```

Generation is not deterministic: a rerun produces a new take on the same brief,
so treat the committed PNGs as the source of truth and the prompts as the spec.
