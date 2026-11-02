# Pixel environment seed

Status: prototype visual target, not final production art.

- Engine: Godot 4.7, side view, 1280×720 logical canvas, default 1600×900 window.
- Existing characters: 64×64 sprite sheets, nearest sampling, baseline at feet; keep their identity.
- Palette roles: navy / teal distance, warm wood and brass, muted green opportunity, orange-red danger.
- Shape language: chunky hard clusters, stepped silhouettes, square UI corners. Important attack shapes must read over the scene.
- First seed: `forest-outpost.png`, generated using the built-in `image_gen` tool. Its exact palette is not yet limited to the requested twenty colors. The renderer uses nearest sampling. Future production requires a deliberate pixel grid and final palette pass.
- Source: `/Users/cdytim/.codex/generated_images/01a191d0-2ef0-7163-8ea3-d12bfc8e9442/exec-38dcb43b-c7ee-49bd-b36f-b4bd5504d371.png`.
- No source image edits or third-party reference images were used. The original output is preserved; this project contains a copy.
- Main menu uses the full seed; arena rendering crops the lower 30% so the baked road cannot be mistaken for a second collision platform. The actual bridge and collisions are engine-authored.
- 2026-11-03: chapters 2–6 now use five generated pixel backgrounds matching this seed, in both the adventure map and playable arenas. See `chapter-background-prompts.md` for the exact prompts and `asset-manifest.json` for dimensions, checksums and provenance. The procedural drawings remain only as missing-asset fallbacks; interaction cues and physics stay engine-authored.
- Existing prop art provenance remains in `assets/props/CREDITS.md`.

## Final generation prompt

Use case: stylized-concept. Asset type: background-only seed image for a 2D side-view pixel-art game, FUNNY BATTLE. Create a wide 16:9 forest outpost ravine background with a distinct handmade 16-bit pixel-art look: readable large pixel clusters, dark teal-blue silhouettes of giant pine trees and distant ruined windmill towers, warm amber lantern windows, a few muted green moss patches, subtle layered depth. Mood playful adventure, an underdog's resourceful counterattack rather than horror. Crisp square pixels and a restrained 20-color palette, no painterly textures, no anti-aliased vector look, no smooth gradients. Composition supports a fixed side-view boss arena: a dark quiet central horizontal combat band around 55–80 percent height, large open central space for a tiny blue-haired fighter and a much larger mechanical guard, but DO NOT draw any characters. Background structures only, no bridge, no floor, no platforms, no foreground trees blocking play space, no HUD, no interface boxes, no text or lettering, no logos, no watermark. Use layered silhouettes and pixel-dithered lighting; top-left ambient moonlight, amber accents low in contrast so game sprites can stand out. Render as a single flat reusable background, no mockup frame, landscape.

## Active chapter palettes — 2026-11-03

The active backgrounds use `*-arena-color-v2.png`. These are built-in imagegen color edits of the same chapter compositions, not redesigned scenes.

| Chapter | Palette |
|---|---|
| Windmill Canyon | moss / jade green |
| Clocktower Workshop | warm copper / brass / sepia |
| Frozen Harbor | ice cyan / silver-white |
| Furnace Railway | coffee brown / iron rust / orange |
| Mechanical Throne | dark purple / antique gold |

Exact edit prompts: `chapter-palette-prompts.md`. Terrain and armor accent colors follow the same palette.
