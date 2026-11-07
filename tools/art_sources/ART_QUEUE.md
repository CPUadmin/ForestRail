# ART QUEUE: what the art generator (GPT) should draw next

LOCAL DISK (preferred, no upload or download needed): the same project is on the owner's disk C: at `C:\Users\Lenovo\Documents\ChatGPT\дрезина`. If you can read and write local files, work there directly: read this file and the task files from that folder, and SAVE every finished image straight into the inbox folder of its pack (paths in the table below, relative to that project folder). Then just say which files you saved.

Repository (fallback): CPUadmin/ForestRail, branch main. This file is the single to-do list for image generation.
Claude (the developer) updates it; the generator reads it.

## How to work (for GPT)

1. Take the FIRST pack below whose status is `waiting for GPT`.
2. Open its `TASK_FOR_GPT.md` (folder is given in the table) and look at the `ref_*` images next to it.
3. Draw ALL images of the pack one by one, in order, exactly as the task says. For packs with 20+ images keep the style identical: re-read the first message block of the task and the `ref_*` images every 6 images.
4. Name every file exactly as in the task headings (for example `card_00_fool.png`).
5. Deliver:
   - if you can write to the repository: put the files into a new branch `art-inbox`, into the folder given in the `inbox` column, one commit per pack, and say so;
   - otherwise give the owner all files in one download (a zip with the exact file names).
6. After delivery, say which images you consider weak (cropped, text on them, wrong style) so that they can be redone.

Never draw letters, numbers or readable text on the images. Never draw the card frame in the card illustrations.

## Packs

| pack | what | status | task | inbox |
|---|---|---|---|---|
| P10 | 22 tarot card illustrations | DONE | tools/art_sources/briefs/P10_tarot_cards/TASK_FOR_GPT.md | tools/art_sources/inbox/P10_tarot_cards/ |
| P11 | 18 gadget icons in 2 sheets of 3x3 (repaint of the sketch ref_icons_sketch.jpg) | DONE | tools/art_sources/briefs/P11_gadget_icons/TASK_FOR_GPT.md | tools/art_sources/inbox/P11_gadget_icons/ |
| P3 | Кабина: панель и рама (3 images) | DONE (accepted, see art_tracker) | tools/art_sources/briefs/P3_cab_glass/TASK_FOR_GPT.md | tools/art_sources/inbox/P3_cab_glass/ |
| P5 | Электровоз (2 images) | DONE (the parts accepted; the body is received, to be checked) | tools/art_sources/briefs/P5_electric_loco/TASK_FOR_GPT.md | tools/art_sources/inbox/P5_electric_loco/ |
| P6 | Станции E и F (3 images) | DONE (accepted, see art_tracker) | tools/art_sources/briefs/P6_stations_ef/TASK_FOR_GPT.md | tools/art_sources/inbox/P6_stations_ef/ |
| P12 | Gadgets on machines: 9 machine images with two gadgets each, 2 sheets of 18 parts, and a Russian text file GADGET_TEXTS_RU.md (GPT designs the look and writes the descriptions; READ the sources listed in the brief first) | DONE (accepted, see art_tracker) | tools/art_sources/briefs/P12_gadgets_on_machines/TASK_FOR_GPT.md | tools/art_sources/inbox/P12_gadgets_on_machines/ |
| P13 | Pole truck: an EMPTY own platform (1 image) and a 3x3 sheet of small parts | DONE | tools/art_sources/briefs/P13_pole_truck/TASK_FOR_GPT.md | tools/art_sources/inbox/P13_pole_truck/ |
| P14 | Rail zeppelin: a CLEAN body (no tail plane, wing pod and propeller blades; the engine behind them painted in) and a 3x3 sheet of the movable parts | DONE (07.11: the redone body accepted; NOT yet connected to the game: it has other proportions than the old cut body, the pivots of the movable parts must be fitted again; do it at the big graphics stage) | tools/art_sources/briefs/P14_zeppelin_parts/TASK_FOR_GPT.md | tools/art_sources/inbox/P14_zeppelin_parts/ |
| P15 | Rocket railcar parts: a 3x3 sheet of exhaust flames and smoke, a 2x2 sheet of the parachute (pack, open, collapsed, cut away), a 3x3 sheet of the start panel parts (cap closed and open, toggle up and down, lamp off and on, start button locked, armed, burning) | DONE (accepted 07.11) | tools/art_sources/briefs/P15_jet_parts/TASK_FOR_GPT.md | tools/art_sources/inbox/P15_jet_parts/ |
| P16 | Oars of the sail car: a 3x3 sheet of oar parts and a landscape image of the rower in three poses (catch, drive, recovery) | DONE (accepted 07.11) | tools/art_sources/briefs/P16_oars/TASK_FOR_GPT.md | tools/art_sources/inbox/P16_oars/ |
| P17 | Pults of the rocket railcar and the rail airship: 4 images (the EMPTY dashboard board; a 3x3 sheet of dials, needles and gauge frames; a 3x3 sheet of levers, slots and knobs; a 3x3 sheet of buttons, lamps and the pull ring); the dashboards are assembled from them, no numerals on dials | DONE (received 07.11, 4 images in the inbox; NOT connected: the owner decided that there will be no separate pults, only the side view and the cab; wait for his word) | tools/art_sources/briefs/P17_pults/TASK_FOR_GPT.md | tools/art_sources/inbox/P17_pults/ |
| STYLE-TEST | ONE card (Wheel of Fortune) in styles 2-7 for the owner to choose a style; style 1 (painting) already exists as card_10_wheel_of_fortune.png | DONE | tools/art_sources/briefs/P10_tarot_cards/STYLE_TEST_RU.md (use the English text blocks; send each as its own image) | tools/art_sources/inbox/P10_tarot_cards/styles/ (names style_2_origami.png, style_3_symbolism.png, style_4_minimal_geometry.png, style_5_artdeco.png, style_6_engraving.png, style_7_stained_glass.png) |
