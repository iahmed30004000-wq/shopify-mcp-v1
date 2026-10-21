---
name: madar-art-prompts
description: Madar's image prompts for ChatGPT and the owner's standing rule for them. Use whenever Madar needs a picture made outside the code (key art, wallpapers, planet panels, empty-state art, celebrations, the app icon, guide illustrations, seasonal art) or whenever the owner asks for prompts. Every prompt lives in prompts.json here and always reaches him as ONE Word file.
---

# Madar image prompts

## The standing rule (owner, 2026-10-21)

- **ChatGPT makes Madar's pictures.** I write the prompts and he runs them; I never generate
  the art myself.
- **Collect them all, always.** Every image prompt goes into `prompts.json` in this folder
  first, then the Word file is rebuilt and sent to him with `SendUserFile`. Prompts are
  never scattered in chat, and the Word file is always the whole collection, not just the
  new prompts.
- Every rebuild bumps `version`, sets `updated`, and adds one line to `log` saying what
  changed (in plain Arabic).

## What ChatGPT is for, and what it is not for

**For:** the home wallpaper at each time of day, the panel each planet opens with, the
first-run guide illustrations, empty-state art, celebration emblems, the app icon and the
splash, seasonal art (Ramadan, Eid).

**Not for** (all of these are code or real fonts):
- Islamic geometric patterns: drawn procedurally, exact, animatable, zero file size.
- Small UI icons: drawn in code so they stay sharp and consistent.
- The planets that orbit on the map: the existing shaders.
- Any text, Arabic lettering, calligraphy or Quran: real licensed fonts only, never inside an
  image (image models garble Arabic, and fake calligraphy that looks like scripture is not
  acceptable).

## Hard rules every prompt carries (they are in `rules_en`, appended automatically)

- No text, letters, numbers, calligraphy, logos or watermarks.
- No brands, franchises or existing characters. **GTA is a feeling we borrow, never its logo,
  characters, fonts, screenshots or sounds** (his own rule: no franchise assets).
- No weapons, no violence.
- People only as small silhouettes from behind or far away, modestly dressed, faces never
  visible; never a prophet, a companion or any religious figure. (Whether people appear at
  all is his call: prompt R1-A-05 exists to show him.)
- Original artwork.

## Consistency

- One ChatGPT conversation per group, so the images come out of one family.
- Time-of-day and seasonal variants are **edits of the approved image** in the same
  conversation ("Edit the approved wallpaper image: same composition..."), not new
  generations.
- Sizes: portrait 1024x1536 (full screens, planet panels), square 1024x1024 (cards, emblems,
  empty states). Transparent PNG for emblems and the icon foreground.
- Every prompt is self-contained (subject + size + style block + rules), because he pastes
  one box at a time from his phone.

## The three directions (round 1) and the chosen one

`styles` holds A «قنديل المدينة» (recommended), B «الأندلس», C «شارع النيون». Round 1 shows
the same four subjects in all three. Round 2 is written in `recommended_style` until he
picks; when he picks, set `recommended_style` to his choice and rebuild, so round 2's boxes
carry his style.

## Real photos

Only from sources whose licence allows it, with the source and licence recorded in
`madar/assets/licenses/` and shown in the app's About screen:
- as **references fed to ChatGPT**: CC0, public domain, the Unsplash licence or the Pexels
  licence only (no share-alike chain into our art);
- **used directly**: any free licence with its credit (Wikimedia Commons per file, NASA,
  ESA/Webb under CC BY 4.0 for the sky).

## Intake (when his images arrive)

He names files by their code (`R1-A-01.png`, `R2-PL-faith.png`) and drops them in a Google
Drive folder «مدار – رسومات» or in the chat. Then: check each against the rules above
(reject any with text or faces), cut out if needed, compress to WebP (full-screen art at most
1440 px wide, cards 720 px), keep the whole art budget under 12 MB in the APK, and credit
them in About as art made for Madar.

## Rebuilding the Word file

```bash
S=<scratchpad>; mkdir -p "$S/docxbuild" && (cd "$S/docxbuild" && npm init -y >/dev/null && npm install docx@9)
NODE_PATH="$S/docxbuild/node_modules" node .claude/skills/madar-art-prompts/build_docx.js \
  --out "$S/out/madar-image-prompts.docx"          # optional: --style A|B|C
```

Then check the structure (every Arabic paragraph `w:bidi`, every Arabic run `w:rtl`, no
Arabic inside the English prompt boxes) and send it with `SendUserFile`.
