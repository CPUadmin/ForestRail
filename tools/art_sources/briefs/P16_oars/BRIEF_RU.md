# Комплект П16 «Вёсла парусной дрезины»

Парусная дрезина (`ref_sail_now.jpg`) на штиле может идти на вёслах: человек сидит на ящике (`ref_sailor_seated.jpg`), тянет мышь, и дрезина едет медленно. Сейчас вёсла в игре временные линии. Нужны настоящие вёсла и поза гребца с сильным объёмом.

Файлы сохраняются в `tools/art_sources/inbox/P16_oars/` с точными именами.

## Первое сообщение (блок 0)

```text
Attached are references for the pack "P16 oars" of a cozy narrow-gauge forest railway game: ref_sail_now.jpg is the CURRENT sail car (a low flatbed with a mast, a cloth sail and a person sitting on a wooden crate), ref_sailor_seated.jpg is the CURRENT painted sitting person (side view, facing right) so that the new rowing poses match his clothes, size and style, ref_style_steam.jpg is the style anchor. When there is no wind the person stows the sail and rows with two long wooden oars that stick out of iron oarlocks on both sides of the platform. I need the oars, the oarlocks and the rower painted separately so that the game can swing them over the car. Common style: hand-painted painterly look, warm worn feel, forest green, charcoal steel, honey wood, cream, aged brass, STRONG VOLUME (bold rounded relief, deep shadows, clear lit and shaded sides), soft light from the upper left, the same painting style as the attached approved references. Strict flat side view, facing right, flat pure magenta #FF00FF background, no ground shadow, no letters, no numbers, no text.
```

### A1 `oars_parts.png`: вёсла и уключины (лист 3 на 3)

```text
Asset: oars_parts. Format: square 1:1. Background: flat pure magenta #FF00FF. Sheet 3 by 3, exactly nine objects, one per cell, centered, same scale family, wide margins, no overlaps, no cell lines, no labels, no ground shadows. Nine parts for rowing, painted with strong volume: 1 a long wooden oar seen from the side, lying HORIZONTAL (a leather-wrapped grip at the left end, a long honey-wood shaft with a brass collar, a broad painted blade at the right end); 2 the same oar tilted up by 25 degrees; 3 the same oar tilted down by 25 degrees; 4 an iron oarlock (a forked iron holder on a short wooden post, mounted on the platform edge); 5 the oarlock with a rope loop and a leather pad; 6 a spare oar tied along a rail (a short bundle of two oars with rope lashing); 7 the oar blade alone, close up, broad, with green paint and a brass tip; 8 the oar grip alone, close up, leather wrapped with a wooden knob; 9 a coiled rope with a wooden toggle (for tying the oars). hand-painted painterly look, warm worn feel, forest green, charcoal steel, honey wood, cream, aged brass, STRONG VOLUME, soft light from the upper left, the same painting style as the attached approved references. No letters, no numbers, no text.
```

### A2 `rower_poses.png`: гребец в трёх позах

```text
Asset: rower_poses. Format: landscape 3:2. Background: flat pure magenta #FF00FF. Three poses of the SAME person as in ref_sailor_seated.jpg (same clothes, cap, face, size and painting style), side view, facing right, sitting on the same wooden crate, drawn side by side in one row with wide margins, no overlaps, no cell lines, no labels, no ground shadows, the crate under each pose, but NO oars (the oars are separate): 1 the CATCH: leaning forward, both arms stretched forward and low, hands holding invisible oar grips; 2 the DRIVE: leaning back, arms pulled in to the chest, legs braced, effort on the face; 3 the RECOVERY: upright and relaxed, hands moving forward at waist height. The crate, the boots and the position of the seat must be at exactly the same place and size in all three poses so that they can be swapped in the game. hand-painted painterly look, warm worn feel, STRONG VOLUME, soft light from the upper left, the same painting style as the attached approved references. No letters, no numbers, no text.
```

## Чек-лист приёмки
1. Человек тот же, что на `ref_sailor_seated.jpg` (одежда, лицо, масштаб); ящик и сиденье в трёх позах на одном месте и одного размера.
2. Вёсла: рукоять слева, лопасть справа, три наклона одного весла в одном масштабе; уключина с вилкой.
3. Нет букв и цифр; фон пурпурный; предметы не обрезаны; лист вёсел ровно девять предметов.

## Что делаю я после получения
Принимаю, вырезаю фон, режу лист, подгоняю масштаб под парусную (длина весла, высота уключины), подключаю вместо временных линий: наклон весла по фазе гребка, поза гребца по фазе (замах, гребок, возврат), показываю кадры «до и после».
