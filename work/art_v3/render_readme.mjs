import fs from 'node:fs';
import {marked} from 'file:///C:/Users/Lenovo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/marked/lib/marked.esm.js';
const root='C:/Users/Lenovo/Documents/ChatGPT/дрезина/ForestRail/assets/art_v3';
const body=marked.parse(fs.readFileSync(root+'/README_RU.md','utf8'));
fs.writeFileSync(root+'/README_RU.html','<!doctype html><html lang="ru"><meta charset="utf-8"><title>Ассеты v3 — подключение</title><style>body{max-width:950px;margin:40px auto;padding:0 25px;background:#f6f1e6;color:#283d33;font:17px/1.7 Segoe UI,Arial}a{color:#35684c}h1,h2{line-height:1.2}h2{margin-top:38px}code{overflow-wrap:anywhere}</style><p><a href="OPEN_ME.html">← Каталог и анимация</a></p>'+body);
