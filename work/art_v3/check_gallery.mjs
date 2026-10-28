import fs from 'node:fs';
import {chromium} from 'file:///C:/Users/Lenovo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/index.mjs';
const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'});
try{
 const page=await browser.newPage({viewport:{width:1440,height:1000},deviceScaleFactor:1});
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto('file:///C:/Users/Lenovo/Documents/Codex/2026-10-27/new-chat/outputs/ForestRail_Art_v3/OPEN_ME.html',{waitUntil:'load'});
 await page.waitForFunction(()=>document.getElementById('error').textContent.startsWith('Ошибка длины'),{timeout:20000});
 await page.screenshot({path:'C:/Users/Lenovo/Documents/ChatGPT/дрезина/work/art_v3/gallery.png'});
 await page.locator('#fleet').screenshot({path:'C:/Users/Lenovo/Documents/ChatGPT/дрезина/work/art_v3/fleet.png'});
 await page.locator('#forest-view').screenshot({path:'C:/Users/Lenovo/Documents/ChatGPT/дрезина/work/art_v3/forest.png'});
 await page.locator('#toggle').click();
 const report=await page.evaluate(()=>({loadedImages:Object.keys(images).length,errorText:document.getElementById('error').textContent,pausedButton:document.getElementById('toggle').textContent,overflow:document.documentElement.scrollWidth>innerWidth,layers:document.querySelectorAll('[data-layer]').length}));
 if(errors.length||report.loadedImages!==28||report.overflow||report.layers!==5)throw new Error(JSON.stringify({errors,report}));
 fs.writeFileSync('C:/Users/Lenovo/Documents/ChatGPT/дрезина/work/art_v3/browser_report.json',JSON.stringify({errors,...report},null,2));
 console.log(JSON.stringify({errors,...report}));
}finally{await browser.close();}
