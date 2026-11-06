# Комплект П15 «Реактивный (ракетный) поезд: пламя, парашют, панель пуска»

Реактивный поезд (картинка `ref_jet_now.jpg`) уже в игре. Сейчас у него нет пламени и дыма из сопла, парашют не нарисован, а панель запуска в кабине (`ref_jet_panel_now.jpg`) нарисована кодом: колпачок, четыре тумблера, лампочки, кнопка «Пуск». Нужны настоящие детали с сильным объёмом в стиле игры. Это **ракетный** двигатель: сопло слева, кабина справа, поезд едет вправо, пламя летит влево.

Файлы сохраняются в `tools/art_sources/inbox/P15_jet_parts/` с точными именами.

## Первое сообщение (блок 0)

```text
Attached are references for the pack "P15 jet parts" of a cozy narrow-gauge forest railway game: ref_jet_now.jpg is the CURRENT rocket railcar (a big brass-and-steel rocket engine with a flared nozzle on the left, a green cab on the right, on a low flatbed; it drives to the right, so the exhaust flies to the LEFT), ref_jet_panel_now.jpg is the CURRENT dashboard panel of its cab drawn by code (a cap over four toggle switches with lamps, a start button, a countdown board, gauges), ref_style_steam.jpg is the style anchor. I need the missing parts painted separately so that the game can put them over the machine: the exhaust flames and smoke, the parachute, and the parts of the start panel. Common style: hand-painted painterly look, warm worn feel, forest green, charcoal steel, honey wood, cream, aged brass, STRONG VOLUME (bold rounded relief, deep shadows, clear lit and shaded sides), soft light from the upper left, the same painting style as the attached approved references. Strict flat side view, flat pure magenta #FF00FF background, no ground shadow, no letters, no numbers, no text. Flames and smoke must be painted with opaque painterly shapes (not a soft glow), so that they survive the removal of the magenta background.
```

### A1 `jet_exhaust.png`: пламя и дым (лист 3 на 3)

```text
Asset: jet_exhaust. Format: square 1:1. Background: flat pure magenta #FF00FF. Sheet 3 by 3, exactly nine objects, one per cell, centered, same scale family, wide margins, no overlaps, no cell lines, no labels, no ground shadows. Every flame or plume is seen from the SIDE, starts at its RIGHT end (the mouth of the nozzle) and streams to the LEFT: 1 a small idle flame (short, orange and yellow); 2 a medium flame with a visible core (longer, yellow-white core, orange outside); 3 a full-thrust flame (very long, white-yellow core, orange body, a few shock diamonds along it, sparks); 4 a soft grey-white smoke plume for the exhaust at low thrust (puffs streaming left); 5 a darker thick smoke plume for high thrust (large rolling puffs); 6 the afterburner flame (extremely long and bright, blue-white core, orange edge, many shock diamonds); 7 a ring of hot air and glow around a nozzle mouth, seen from the side as a vertical oval (painted, semi-bright rim); 8 a handful of flying sparks and embers streaming left; 9 the ignition flash (a short fat burst of white and yellow with rays). hand-painted painterly look, warm worn feel, STRONG VOLUME (bold rounded shapes, clear lit and shaded sides), the same painting style as the attached approved references. No letters, no numbers, no text.
```

### A2 `jet_parachute.png`: парашют (лист 2 на 2)

```text
Asset: jet_parachute. Format: square 1:1. Background: flat pure magenta #FF00FF. Sheet 2 by 2, exactly four objects, one per cell, centered, same scale family, wide margins, no overlaps, no cell lines, no labels, no ground shadows. Four views of the braking parachute of the rocket railcar, painted in strong volume with patched cream canvas, green stripes, brass rings and thick rope: 1 the PACK: a folded canvas bundle in a brass-strapped box that sits on the rear deck, side view, small, with a short ring-pull handle; 2 the OPEN parachute streaming BEHIND the train: seen from the side, a big round-bellied canopy on the LEFT, long taut rope lines converging to a single brass ring on the RIGHT where it hooks to the train; 3 the same parachute seen at a slight angle, foreshortened and partly collapsed, lines slack; 4 the parachute CUT AWAY after the stop: a crumpled heap of canvas lying on the ground with a few loose lines and a brass ring. hand-painted painterly look, warm worn feel, forest green, charcoal steel, honey wood, cream, aged brass, STRONG VOLUME, soft light from the upper left, the same painting style as the attached approved references. No letters, no numbers, no text.
```

### A3 `jet_panel_parts.png`: детали панели пуска (лист 3 на 3)

```text
Asset: jet_panel_parts. Format: square 1:1. Background: flat pure magenta #FF00FF. Sheet 3 by 3, exactly nine objects, one per cell, centered, same scale family, wide margins, no overlaps, no cell lines, no labels, no ground shadows. Nine parts of the start panel in the cab of the rocket railcar, all seen from the FRONT (flat, facing the viewer), painted with strong volume as brass, steel and enamel: 1 a CLOSED protective cap (a hinged riveted steel plate that covers four toggle switches, with a small brass latch and a hinge at the top); 2 the same cap OPEN (the plate swung up on its hinge, behind it a dark recess with four empty switch sockets); 3 one toggle switch in the UP position (a brass lever pointing up from a round steel base, with a ring nut); 4 the same toggle in the DOWN position; 5 a signal lamp OFF (a dark glass dome in a brass ring); 6 the same lamp ON, green glowing glass; 7 a big start button LOCKED (a dark dead red button under a steel guard bar, looks unusable); 8 the same start button ARMED (bright red, guard bar raised, ready); 9 the same start button BURNING (green lit, with a halo painted as an opaque ring). hand-painted painterly look, warm worn feel, forest green, charcoal steel, honey wood, cream, aged brass, STRONG VOLUME, soft light from the upper left, the same painting style as the attached approved references. No letters, no numbers, no text.
```

## Чек-лист приёмки
1. Пламя и дым идут влево от правого конца (сопло слева, поезд едет вправо); формы плотные, без мягкого свечения, которое пропадёт при вырезке фона.
2. Парашют: раскрытый купол слева, стропы сходятся к кольцу справа; упаковка небольшая, узнаваема.
3. Панель: колпачок закрыт и открыт, тумблер вверх и вниз, лампа выкл и вкл, кнопка трёх состояний в одном размере и стиле.
4. Нет букв и цифр; фон пурпурный; предметы не обрезаны краем кадра; листы ровно по 9, 4, 9 предметов.

## Что делаю я после получения
Принимаю, вырезаю фон, режу листы на ячейки, подгоняю под размеры игры (пламя по соплу, парашют по задней площадке и сцепке, детали панели по сетке пульта), подключаю отдельными файлами, показываю кадры «до и после». Пламя и дым связываю с тягой (три размера по рычагу, форсаж отдельно), парашют с кольцом, панель с тумблерами, лампочками и кнопкой. Код-рисунок панели остаётся запасным.
