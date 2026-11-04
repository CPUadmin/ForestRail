# Комплект П2б «Парусник сидя»: промпт для GPT

Просьба владельца 04.11.2026: на парусной дрезине водитель должен не стоять, а сидеть, так легче тянуться к шкоту и закреплённому парусу. Это один новый рисунок: тот же человек, но сидящий.

## Что сейчас (кадр `ref_sail_standing_now.jpg`, красная рамка)

Водитель стоит в полный рост на корме. Ему далеко тянуться до утки на палубе, поэтому я уже сделал, что при закреплённом парусе рука просто висит вдоль тела. Сидящий водитель решает это естественно: шкот и утка рядом с рукой.

## Что сделать

1. Новый чат (или продолжите чат пакета П2). Если GPT читает репозиторий через подключение, фраза:

```
Открой в репозитории CPUadmin/ForestRail (ветка main) файл tools/art_sources/briefs/P2b_sailor_seated/TASK_FOR_GPT.md, посмотри кадры ref_* рядом с ним и выполни задание: одна картинка.
```

2. Если картинки из репозитория он не открывает, приложите четыре файла `ref_*` из этой папки и вставьте блок из `PROMPTS_FOR_GPT.txt`.
3. Сохраните результат как `sailor_seated.png` в `tools/art_sources/inbox/P2b_sailor_seated/` и напишите мне. Слежение за папкой работает.

## Картинка

### A1 `sailor_seated.png`: тот же человек сидя (квадрат, пурпурный фон)

Обе руки в кадре прошу не показывать: руки я подставляю отдельными частями из прошлого пакета (рукав, предплечье, кисть), чтобы они дотягивались до шкота.

```text
Attached are references for the pack "P2b sailor seated". ref_worker.png is the CHARACTER: keep his face, grey-brown moustache, flat cap, dark olive-green wool work jacket, brown trousers, worn boots, weathered skin and proportions exactly. ref_style_handcar.jpg and ref_style_steam.jpg are the STYLE ANCHORS: match their painterly brush texture, warm worn look, palette and soft light from the upper left. ref_sail_standing_now.jpg shows how he stands now on the sailing rail trolley (red box). I will ask for one image.
```

```text
Asset: sailor_seated. Format: square 1:1. Background: flat pure magenta #FF00FF, no shadow, no floor, nothing else in the frame.
The SAME man as in ref_worker.png, but SEATED, in strict flat side view facing right: sitting on a small low wooden crate (draw the crate too: plain weathered planks, a rope handle hole, about knee high, seen from the side), back straight and leaning very slightly forward, thighs horizontal, knees bent at about 90 degrees, both worn boots flat on the ground in front of the crate, head up and looking forward along the track. BOTH ARMS ARE HIDDEN behind his body so that none is visible, only the rounded jacket shoulder seam on the near side is seen, because separate arm parts will be attached later. The whole figure with the crate occupies about 70 percent of the frame height, centered, with wide empty margins on every side, nothing cropped. Hand-painted, painterly brush texture, warm and slightly worn, early 20th century Russian northern railway, the same style, fabric, colors and light as the attached references. No letters, no numbers, no other objects, no cast shadow.
```
Назначение: заменяет стоящего водителя на парусной.

## Чек-лист приёмки

1. Тот же человек: лицо, усы, кепка, куртка, брюки; не другая внешность.
2. Сидит боком вправо на невысоком ящике, колени около 90 градусов, ботинки на земле.
3. Рук не видно (допустим только плечевой шов куртки), чтобы не было двух рук.
4. Ровный пурпурный фон, без тени и пола, фигура целиком, поля не меньше 8%.
5. Нет букв и цифр, стиль как у образцов.

Если что-то не так, одной фразой из `docs/GPT_ART_BRIEF_RU.md`, раздел 10; например: `Same character as the attached ref_worker.png, identical face and clothes; hide both arms behind the body.`

## Что делаю я после получения

Вырезаю фон, ставлю сидящего водителя на корму парусной (с учётом ящика и палубы), пересчитываю плечо и точки хвата шкота и утки, показываю кадры «до и после» в трёх размерах окна.
