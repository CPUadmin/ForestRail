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

## P19 / wear_overlays.png  [open]
What is wrong: drawn on magenta. The overlays are half-transparent (soot, smoke, scratches), so after the key the magenta stays in them as a pink tint.
What to change: the same 9 overlays on a flat pure BLACK #000000 background, exactly as the task says (light, smoke and see-through things go on black).
Keep: the content, order and size of all 9 cells.

## P21 / gear_gate.png  [open]
What is wrong: the plate shows a herringbone of arrows, not a gear gate.
What to change: a real gearbox gate seen from above: an iron plate with an H-pattern slot for 5 forward gears and reverse (three vertical slots joined by one horizontal channel, plus a short side slot for reverse), worn edges, 4 screws; no numbers. The second item: the brass blanking plate with 2 screws, sized to cover ONE vertical slot end.
Keep: style, colours and the 3:2 sheet of 2 items.

## P21 / contactor_parts.png  [open]
What is wrong: cell 3 (burnt fuse) does not read as burnt (the glass is just black); cell 7 (torn wires) looks clean and new.
What to change: cell 3: clear glass with a soot smear inside and a visibly BROKEN filament; cell 7: two copper wire ends with charred black tips, frayed strands and a bit of melted insulation.
Keep: all other cells unchanged (redraw the whole sheet, but only these two cells may differ).
