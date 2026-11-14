# Renders the mockups m*.html of this folder into PNG 1600x900 with the Edge browser (Playwright).
# python qa/ui_mockups/render.py [names...]
import sys
from pathlib import Path
from playwright.sync_api import sync_playwright

here = Path(__file__).resolve().parent
names = sys.argv[1:] or sorted(p.stem for p in here.glob("m*.html"))
with sync_playwright() as p:
    browser = p.chromium.launch(channel="msedge")
    page = browser.new_page(viewport={"width": 1600, "height": 900})
    for name in names:
        page.goto((here / f"{name}.html").as_uri())
        page.wait_for_timeout(300)
        page.screenshot(path=str(here / f"{name}.png"))
        print("rendered", name)
    browser.close()
