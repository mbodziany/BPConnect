"""Buduje samodzielną wersję strony (pełny dokument HTML, lokalne three.js) w katalogu dist/.

Użycie: python3 build_site.py [ścieżka/do/three.min.js]
index.html jest pisany jako fragment (format artefaktu claude.ai); tu dostaje własny szkielet.
"""
import pathlib, shutil, sys

here = pathlib.Path(__file__).parent
dist = here / "dist"
dist.mkdir(exist_ok=True)
page = (here / "index.html").read_text(encoding="utf-8")
cdn = "https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"
if len(sys.argv) > 1:
    shutil.copy(sys.argv[1], dist / "three.min.js")
    page = page.replace(cdn, "three.min.js")
head = (
    '<!doctype html>\n<html lang="pl">\n<head>\n<meta charset="utf-8">\n'
    '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">\n'
    '<meta name="theme-color" content="#00864a">\n'
    '<link rel="apple-touch-icon" href="apple-touch-icon.png">\n'
    '<link rel="manifest" href="manifest.webmanifest">\n'
    "<style>*,*::before,*::after{box-sizing:border-box}body{margin:0}"
    ":root{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}</style>\n"
    "</head>\n<body>\n"
)
# Tytuł, metadane i style z fragmentu idą do <head>, treść do <body>.
split = page.index('<div class="app"')
top = page[:split].replace('<meta name="claude:viewport-fit-sides" content="cover">\n', "")
head = head.replace("</head>\n<body>\n", top + "</head>\n<body>\n")
(dist / "index.html").write_text(head + page[split:] + "</body>\n</html>\n", encoding="utf-8")
for name in ["cube.js", "app.js", "manifest.webmanifest", "apple-touch-icon.png", "icon-512.png"]:
    shutil.copy(here / name, dist / name)
print("dist:", sorted(p.name for p in dist.iterdir()))
