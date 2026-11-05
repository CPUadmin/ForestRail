# Комплект П14 «Рельсовый цеппелин: чистый кузов и подвижные части»

Цеппелин (картинка другого помощника, `ref_zeppelin_now.jpg`) в игре теперь имеет **подвижные** части: хвостовое оперение, крыло-гондолу (щитки) и лопасти винта. Пока я вырезал их из готовой картинки (`ref_zeppelin_cut_parts.jpg`, видны швы и недорисованный мотор под крылом). Нужен **чистый кузов без подвижных частей** и **отдельные части**, нарисованные заново, чтобы всё стыковалось без швов.

Файлы сохраняются в `tools/art_sources/inbox/P14_zeppelin_parts/` с точными именами.

## Первое сообщение (блок 0)

```text
Attached are references for the pack "P14 zeppelin parts" of a cozy narrow-gauge forest railway game: ref_zeppelin_now.jpg is the CURRENT rail zeppelin (a short railcar with a pusher propeller at the back, a tail plane on a fin, a small wing pod on the engine and a green-and-grey cab), ref_zeppelin_cut_parts.jpg shows the movable parts that were cut out of it by hand (a tail plane, a wing pod, two propeller blades) so that you see exactly what has to become separate, ref_style_steam.jpg is the style anchor. I need the same machine, with the same proportions, colors and details, but in two forms: (1) the body CLEAN, with the tail plane, the wing pod and the propeller blades removed and the parts behind them painted in (the engine barrel under the wing, the bare fin top, the bare spinner of the propeller); (2) a sheet of the movable parts painted separately, so that they can turn on pivots in the game. Common style: hand-painted painterly look, warm worn feel, forest green, charcoal steel, honey wood, cream, aged brass, STRONG VOLUME (bold rounded relief, deep shadows, clear lit and shaded sides), soft light from the upper left, the same painting style as the attached approved references. Strict flat side view, facing right, flat pure magenta #FF00FF background, no ground shadow, no letters, no numbers, no text.
```

### A1 `zeppelin_body_clean.png`: чистый кузов цеппелина

```text
Asset: zeppelin_body_clean. Format: landscape 2:1, the same framing and proportions as ref_zeppelin_now.jpg. Background: flat pure magenta #FF00FF. A strict flat SIDE view of the rail zeppelin facing right, EXACTLY like ref_zeppelin_now.jpg (same cab with two windows and a lamp, same engine barrel with the copper pipe and the green vent panel, same platform with springs and wheels boxes, same fin) but WITHOUT the movable parts: no horizontal tail plane on top of the fin (the top of the fin is bare and finished with a neat brass cap), no small wing pod on the engine (the engine barrel under it is fully painted: grey steel with brass hoops, rivets, the continuation of the copper pipe and the mount bracket where the wing pod used to be, a short brass pivot pin), and no propeller blades (only the brass hub with a rounded spinner cap in the centre of the propeller shaft). Everything else unchanged. hand-painted painterly look, warm worn feel, forest green, charcoal steel, honey wood, cream, aged brass, STRONG VOLUME (bold rounded relief, deep shadows, clear lit and shaded sides), soft light from the upper left, the same painting style as the attached approved references. No person, no letters, no numbers, no text, no ground shadow.
```

### A2 `zeppelin_parts.png`: подвижные части (лист 3 на 3)

```text
Asset: zeppelin_parts. Format: square 1:1. Background: flat pure magenta #FF00FF. Sheet 3 by 3, exactly nine objects, one per cell, centered, drawn in the SAME SCALE as in ref_zeppelin_now.jpg (so that each part fits the machine), wide margins, no overlaps, no cell lines, no labels, no ground shadows, every part in strict flat side view facing right with the pivot end clearly visible. Nine parts of the rail zeppelin, painted with strong volume: 1 the horizontal tail plane (a long riveted grey bar with a green rounded tip on the right and a green lower lip on the left, with a brass hinge bolt in the middle); 2 the wing pod (a pointed streamlined pod, green nose at the left, grey riveted body, a small brass cap on top and a short mount bracket underneath); 3 the same wing pod with its flap hinged open (the rear half of the pod tilted down on a brass hinge); 4 a tall slim propeller blade (rounded tip, riveted grey metal, a brass root collar), seen exactly from the side, standing upright; 5 the same blade seen turned by about 40 degrees (shorter, wider, showing its face); 6 the same blade turned by about 70 degrees (very short and broad); 7 a brass propeller spinner cap with a ring; 8 a pair of brass hinge brackets for the flaps; 9 a larger wing pod (about 20 percent longer, the upgrade version, same style). hand-painted painterly look, warm worn feel, forest green, charcoal steel, honey wood, cream, aged brass, STRONG VOLUME (bold rounded relief, deep shadows, clear lit and shaded sides), soft light from the upper left, the same painting style as the attached approved references. No letters, no numbers, no text.
```

## Чек-лист приёмки
1. Кузов один в один как `ref_zeppelin_now.jpg`: те же кабина, мотор, платформа, колёсные буксы, плавник; нет оперения, крыла-гондолы и лопастей; на месте крыла дорисован мотор, видны крепление и ось.
2. Лист: ровно девять предметов, по одному в ячейке, масштаб как у машины.
3. Нет букв и цифр; фон пурпурный; предмет не обрезан краем кадра.

## Что делаю я после получения
Принимаю, вырезаю фон, подгоняю чистый кузов под текущие координаты (ось винта, оси крыла и оперения те же), заменяю вырезки частями из листа, подключаю лопасти под разные углы поворота, крыло с открытыми щитками и крыло побольше (улучшение «Крыло»), показываю кадры «до и после».
