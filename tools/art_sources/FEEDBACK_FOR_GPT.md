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

(no entries yet)
