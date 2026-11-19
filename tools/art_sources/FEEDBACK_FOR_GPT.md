# FEEDBACK FOR GPT: what Claude asks to redo

Claude (the developer) writes here after checking a delivered pack. GPT reads this file on every run, BEFORE taking a new pack.

How to work (for GPT):
1. Find the entries with status `open`.
2. Redraw ONLY the named files, exactly as the note says; keep everything else of the pack unchanged.
3. Save the new files into the same inbox folder under the SAME names, but with the suffix `_v2` (`_v3`…): for example `wear_icons_v2.png`. Never overwrite the old file.
4. Under the entry write one line `GPT: done <date>, files: ...` (if you can write files), or say it in the reply.
5. Claude checks again and sets the status to `closed`, or writes a new note.

Format of an entry:

```
## <pack> / <file>  [open | closed]
What is wrong: ...
What to change: ...
Keep: ...
```

---

## P32 / electric_cab_concept_6_simple.png  [open]
The owner's choice to develop (19.11). Redraw it as `electric_cab_concept_6_simple_v2.png`, the same scene, style, size (16:9) and layout.
What is wrong and what to change:
1. The hood ahead stands exactly on the post between the two front windows: half of it is in each window and the track is hidden under it. The driver must see the road. Make the hood narrower and shift it so that the rails run clearly visible into the distance in the LEFT front window, with the hood's end and lamp ahead. The slats on top of the hood read as a staircase: put the louvres on the hood's SIDES as vertical grilles, the top stays smooth with the resistor domes.
2. Missing parts that the game has:
   - the five signal lamps (green, amber, red, red, blue; no text) in one row in the middle section;
   - a small round clock.
3. The small half-round gauge under the speedometer becomes the AMMETER with a centre zero: the needle stands in the middle at rest, the left half of the scale is blue (recharge), the right half orange (draw). Draw the needle a little to the right.
4. The tall neon thermometer glows over its whole height, so no level can be read, and it is the brightest thing on the screen, brighter than the speedometer. Show a LEVEL: the glowing column fills about 60% from the bottom (cyan below turning violet at the top of the column), the tube above it is dark glass. Make the glow softer.
5. Remove the thin green art-deco stripes at the sides of the middle panel.
Keep exactly as they are (the owner likes them):
- the small forward/reverse toggle with arrows;
- the rainbow segment bar at the top of the middle section (it is the battery CHARGE): only light about 8 of the 12 segments, the rest dark;
- the horn button, the headlamp toggle and the wiper toggle with their pictograms, and the parked wipers;
- the contactor door with the porthole showing the twisted wires, the knife switch, the red emergency button, the lightning plate, the handles, the marble, the green riveted walls, the copper wire on porcelain insulators.
No letters, no numbers.

GPT: done 19.11.2026, files: electric_cab_concept_6_simple_v2.png

## P19 / wear_overlays.png  [closed 14.11.2026: the _v2 accepted by Claude]
What is wrong: drawn on magenta. The overlays are half-transparent (soot, smoke, scratches), so after the key the magenta stays in them as a pink tint.
What to change: the same 9 overlays on a flat pure BLACK #000000 background, exactly as the task says (light, smoke and see-through things go on black).
Keep: the content, order and size of all 9 cells.
GPT: done 14.11.2026, files: wear_overlays_v2.png

## P21 / gear_gate.png  [closed 14.11.2026: the _v2 accepted by Claude]
What is wrong: the plate shows a herringbone of arrows, not a gear gate.
What to change: a real gearbox gate seen from above: an iron plate with an H-pattern slot for 5 forward gears and reverse (three vertical slots joined by one horizontal channel, plus a short side slot for reverse), worn edges, 4 screws; no numbers. The second item: the brass blanking plate with 2 screws, sized to cover ONE vertical slot end.
Keep: style, colours and the 3:2 sheet of 2 items.
GPT: done 14.11.2026, files: gear_gate_v2.png

## P21 / contactor_parts.png  [closed 14.11.2026: the _v2 accepted by Claude]
What is wrong: cell 3 (burnt fuse) does not read as burnt (the glass is just black); cell 7 (torn wires) looks clean and new.
What to change: cell 3: clear glass with a soot smear inside and a visibly BROKEN filament; cell 7: two copper wire ends with charred black tips, frayed strands and a bit of melted insulation.
Keep: all other cells unchanged (redraw the whole sheet, but only these two cells may differ).
GPT: done 14.11.2026, files: contactor_parts_v2.png

## P29 / key_end_on.png  [closed 16.11: redone in place, all three keys whole]
The third cell (65°) is broken: the key is longer than its cell, its lower end is cut off and a piece of it lies in the second cell (around x 855–880, y 575–610). Please redo the sheet as key_end_on_v2.png: the same three keys (0°, 35°, 65°), each WHOLE inside its own 512×512 cell with at least 40 px free on every side (make the key a little shorter if needed, the same length in all three), axis at the cell centre, nothing crossing into a neighbour cell. Canvas exactly 1536×512.
