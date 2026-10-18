# Kostka – asystent układania kostki Rubika (iPhone)

Robisz zdjęcia 6 ścian kostki, a aplikacja:

1. **rozpoznaje kolory** (z możliwością ręcznej poprawki na siatce),
2. **sprawdza**, czy taki układ w ogóle da się ułożyć (wykrywa błędnie rozpoznane naklejki),
3. **układa kostkę metodą warstwową** (metoda dla początkujących, 7 etapów),
4. **prowadzi krok po kroku**: animowana kostka 3D, ruch po ruchu, z informacją jak trzymać kostkę
   i z wyjaśnieniem, **dlaczego** dany ruch/algorytm działa.

## Uruchomienie

Potrzebny Mac z **Xcode 16** lub nowszym i iPhone z iOS 17+.

1. Otwórz `Kostka.xcodeproj`.
2. W ustawieniach targetu *Kostka* → *Signing & Capabilities* wybierz swój zespół (wystarczy darmowe Apple ID).
3. Podłącz iPhone’a, wybierz go jako cel i naciśnij ▶︎.

W symulatorze nie ma aparatu – użyj „Wpisz kolory ręcznie” albo „Wypróbuj na przykładzie”.

## Jak skanować

Trzymaj kostkę **żółtym środkiem do góry i zielonym do aparatu** (klasyczny schemat kolorów),
wpasuj ścianę w siatkę 3×3 i rób zdjęcia w kolejności: przód → prawa → tył → lewa
(za każdym razem ćwierć obrotu całej kostki w lewo), potem góra (zielony na dole kadru)
i dół (zielony na górze kadru). Najlepiej przy równym, dziennym świetle – w razie potrzeby włącz latarkę.

## Struktura

| Ścieżka | Zawartość |
| --- | --- |
| `CubeCore/` | Pakiet Swift: model kostki, solver z opisami po polsku, rozpoznawanie kolorów, walidacja. Bez zależności od UIKit – testy: `cd CubeCore && swift test`. |
| `Kostka/` | Aplikacja SwiftUI: skaner (AVFoundation), edytor siatki, odtwarzacz rozwiązania (SceneKit). |

### Metoda (etapy)

1. Biały krzyż na dole
2. Narożniki pierwszej warstwy – `R U R' U'` powtarzane
3. Środkowa warstwa – `U R U' R' U' F' U F` / `U' L' U L U F U' F'`
4. Żółty krzyż – `F R U R' U' F'`
5. Krawędzie górnej warstwy – `R U R' U R U2 R'`
6. Narożniki na swoje miejsca – `U R U' L' U R' U' L`
7. Obrót narożników – `R' D' R D` powtarzane

Ruchy są zawsze podawane względem tego, jak trzymasz kostkę (żółty u góry, wskazany środek do siebie).
