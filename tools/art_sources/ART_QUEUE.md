# ART QUEUE: what the art generator (GPT) should draw next

Repository: CPUadmin/ForestRail, branch main. This file is the single to-do list for image generation.
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
| P10 | 22 tarot card illustrations (A1-A3 are DONE: continue with A4) | waiting for GPT | tools/art_sources/briefs/P10_tarot_cards/TASK_FOR_GPT.md | tools/art_sources/inbox/P10_tarot_cards/ |
