# Kostka – asystent układania kostki Rubika (wersja webowa)

Aplikacja w przeglądarce, działa też na iPhonie (Safari → Udostępnij → „Do ekranu początkowego”).

1. **Skanowanie:** robisz zdjęcie każdej z 6 ścian i dopasowujesz siatkę 3×3 do naklejek.
2. **Sprawdzenie kolorów:** siatka kostki z możliwością poprawek i sprawdzeniem, czy układ da się ułożyć.
3. **Rozwiązanie metodą warstwową** (7 etapów): animowana kostka 3D, ruch po ruchu,
   informacja jak trzymać kostkę i wyjaśnienie, dlaczego każdy algorytm działa.

## Pliki

| Plik | Zawartość |
| --- | --- |
| `web/cube.js` | Rdzeń: model kostki, rozpoznawanie kolorów, walidacja, solver z opisami po polsku. Bez zależności. |
| `web/app.js` | Interfejs: skanowanie, edytor siatki, odtwarzacz z kostką 3D (three.js r128 z cdnjs). |
| `web/index.html` | Strona i style. |
| `web/test.js` | Testy rdzenia: `node web/test.js 1000` (układa 1000 losowych pomieszań). |

## Gdzie działa

Na serwerze mikr.us (natalia148): **https://kostka.mikrus.dev/** – statyczne pliki w `/var/www/kostka`, nginx na `[::]:8148`.

Aktualizacja: `cd web && python3 build_site.py ścieżka/do/three.min.js` (three.js r128), potem skopiować zawartość `web/dist/` do `/var/www/kostka`.

## Uruchomienie lokalne

```sh
cd web && python3 -m http.server 8000
```

i otwórz `http://localhost:8000`. Na telefonie zdjęcia wybiera się przez pole pliku, więc https nie jest wymagane.
