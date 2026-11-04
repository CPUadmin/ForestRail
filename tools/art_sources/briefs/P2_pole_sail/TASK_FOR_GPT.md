# TASK FOR GPT: pack П2 (Шестовая и парусная)

You are the art generator for "Лесная колея" (Forest Rail), a cozy 2D side-view narrow-gauge forest railway game. Produce the images below ONE BY ONE, one finished image per message, following the style rules in the project instructions (hand-painted painterly look, warm and slightly worn, forest green #466c51, charcoal steel #29383b, honey wood, cream #f5ecd6, aged brass #bb964f, soft light from the upper left, strict flat side view, no letters or numbers, subject centered with margins, flat pure magenta #FF00FF background unless another is named, no shadows or glow touching the background).

## References
Open each reference (or use the files the owner attached). The two ref_style_* images are the STYLE ANCHORS; match them exactly.

If you read the repository through a GitHub connection, the same files are in the repo at tools/art_sources/briefs/P2_pole_sail/ :

- tools/art_sources/briefs/P2_pole_sail/ref_pole_now.jpg
- tools/art_sources/briefs/P2_pole_sail/ref_sail_now.jpg
- tools/art_sources/briefs/P2_pole_sail/ref_style_handcar.jpg
- tools/art_sources/briefs/P2_pole_sail/ref_style_steam.jpg
- tools/art_sources/briefs/P2_pole_sail/ref_worker.png

If the repository is public, the direct links are:

- https://raw.githubusercontent.com/CPUadmin/ForestRail/main/tools/art_sources/briefs/P2_pole_sail/ref_pole_now.jpg
- https://raw.githubusercontent.com/CPUadmin/ForestRail/main/tools/art_sources/briefs/P2_pole_sail/ref_sail_now.jpg
- https://raw.githubusercontent.com/CPUadmin/ForestRail/main/tools/art_sources/briefs/P2_pole_sail/ref_style_handcar.jpg
- https://raw.githubusercontent.com/CPUadmin/ForestRail/main/tools/art_sources/briefs/P2_pole_sail/ref_style_steam.jpg
- https://raw.githubusercontent.com/CPUadmin/ForestRail/main/tools/art_sources/briefs/P2_pole_sail/ref_worker.png

## First message of the pack

```text
Attached are references for the pack "P2 pole and sail". ref_style_steam.jpg and ref_style_handcar.jpg are the STYLE ANCHORS: match their painterly brush texture, warm worn look, palette and soft light from the upper left exactly. ref_worker.png is the worker whose clothes, skin tone and proportions every new part must match. ref_pole_now.jpg and ref_sail_now.jpg show what is wrong now (flat code-drawn parts inside the red boxes) and must be replaced. I will ask for four images one by one. Return one image per request, with the background I name.
```

## Images

### 1. pole_parts.png

Format: 3:2. Background: magenta.

```text
Asset: pole_parts. Format: landscape 3:2. Background: flat pure magenta #FF00FF, no shadow, no floor.
A sheet with THREE separate straight horizontal segments of one wooden punting pole for a hand-pushed forest rail trolley, stacked vertically with wide empty margins between them, each segment as wide as 90% of the frame and about 11% of the frame tall, all drawn perfectly straight and horizontal in flat side view, the same pole.
Top segment: the HEAD of the pole: weathered pale pine, visible grain, a small rounded wooden end with a thin iron cap and one rivet, a leather-wrapped hand grip near the end, darkened and polished where hands slide.
Middle segment: PLAIN SHAFT: weathered pine with grain, a few small knots, two old repair bindings of tarred cord, slightly worn and darker in the middle.
Bottom segment: the FOOT of the pole: weathered pine ending in a forged iron-shod pointed tip, a riveted iron socket collar with two rivets, a long tapered spike with small nicks, a trace of rust.
Hand-painted, painterly brush texture, warm and slightly worn, early 20th century Russian northern railway, same style as the attached steam locomotive. No letters, no numbers, no people.
```

### 2. worker_arm_parts.png

Format: 1:1. Background: magenta.

```text
Asset: worker_arm_parts. Format: square 1:1. Background: flat pure magenta #FF00FF, no shadow.
The attached ref_worker.png is the character: dark olive-green wool work jacket, brown trousers, flat cap, weathered skin. Draw the ARM PARTS of this exact same worker as four separate pieces on one sheet, each piece centered in its own quarter of the frame with wide margins, all in strict flat side view, painted in exactly the same style, fabric, colors and light as the worker:
(1) the UPPER ARM in a jacket sleeve, drawn straight and horizontal, slightly bent fabric folds, rounded shoulder end on the left and rounded elbow end on the right, about 3 times longer than thick;
(2) the FOREARM in the same sleeve with a button cuff, straight and horizontal, elbow end on the left, wrist on the right;
(3) a bare weathered HAND with a rolled-up cuff, fingers closed in a fist wrapped around a thin round rod, the rod itself shown crossing the fist horizontally;
(4) the same HAND with fingers open and relaxed, palm facing down, hanging.
Hand-painted, painterly, warm and slightly worn, no outline glow, no letters, no other body parts.
```

### 3. sail_cloth.png

Format: 3:2. Background: full-bleed.

```text
Asset: sail_cloth. Format: landscape 3:2. Full-bleed texture: the cloth fills the whole frame edge to edge, no background, no cut-out shape.
A flat piece of old heavy cotton sailcloth, cream-white to pale ivory, taut and seen straight from the front, slightly irregular canvas weave, horizontal panel seams every 12% of the height with double stitching, two small hand-sewn patches in slightly different tones, faint soft folds and light wear near the edges, a hemmed border with fine stitching along the top and bottom edges, a couple of small brass grommets near the left edge. Light comes softly from the upper left. Hand-painted, painterly, warm and slightly worn, same style as the attached references. No mast, no ropes, no text, no marks, no shadows cast on anything.
```

### 4. sail_hardware.png

Format: 1:1. Background: magenta.

```text
Asset: sail_hardware. Format: square 1:1. Sheet 3 by 3, one flat pure magenta #FF00FF background for the whole sheet, exactly nine objects, one per cell, centered, same scale family, wide margins, no overlaps, no cell lines, no labels.
Nine small pieces of rigging for a hand-built wooden rail sailing trolley, each in strict flat side view, hand-painted, painterly, warm and slightly worn, aged brass, dark iron and weathered wood, same style as the attached references:
1 a wooden mast top cap with a brass fitting and a small pulley;
2 a single wooden block (pulley) with a rope through it;
3 a horn-shaped wooden cleat for belaying a rope;
4 a brass-ringed grommet with a short lashing rope;
5 a coil of thick hemp rope, lying flat in side view;
6 a forged iron shackle;
7 a small triangular wind pennant on a short brass pole, red and cream stripes, gently waving to the right;
8 a wooden boom end with an iron cap and a rope eye;
9 an iron deck fitting (a ring bolt on a small plate) for fastening a rope.
No letters, no numbers, no people.
```

## Delivery
After each image say its exact file name (as above) and which background you used. When all are done, list the file names in order. The owner saves them into `tools/art_sources/inbox/P2_pole_sail/` with exactly these names. If an image fails the checks in the brief (letters, shadows, cropped subject, checkerboard instead of a flat background), redo it once before showing it.
