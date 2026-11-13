# Plan: Öffnungs-Fläche, zweite Fassung (2026-11-13)

Spieler-Wünsche nach dem Modul-Paket. Baut auf `docs/plan_paket_lager.md` und `docs/plan_modul_paket.md` auf.

## Gemessen (1280 × 720, 37,5 px/Welt, Display 5094 × 3180)
- Lager: x 3719,6–5074,1, y 1304,8–1874,8.
- Öffnungs-Fläche heute: x 3719,6–4724,2, y 1897,3–2343,5 (1005 × 446).
- Magazin-Grube (`PIT_MAGAZIN`): x 2920,7–3881,7, y 2669,6–3038,7. Werkstatt-Zeile und Info-Schirm enden ebenfalls bei x ≈ 3885 — die heutige Fläche überdeckt sie links um ~160 px.

## 1. Bis hinunter zum Magazin
Die Fläche rückt mit ihrer LINKEN Kante rechts an Werkstatt/Info-Schirm/Magazin heran (EINE Fuge, `LAYOUT_SIZE.x * 0,005` wie überall), ihre OBERKANTE bleibt eine Fuge unter dem Lager, und ihre UNTERKANTE liegt bündig mit der Unterkante der Magazin-Grube. Rechts endet sie höchstens am Lager-Rand (bzw. eine Kante vor dem Displayrand, `PACK_AREA_EDGE`); die Anzeige wächst NICHT. Sie wird dadurch deutlich höher und etwas schmaler. Layout neu wählen: hoch statt breit heißt, die Aufstellung bekommt mehr Reihen (`lineup_grid` wählt schon nach Fläche — prüfen, für 1..10 Würfel, Karten und Module); die linke Spalte (Hülle, Kopf, Walze, Energie, Knöpfe) darf zur Kopfzeile werden, wenn das besser paßt — der Agent misst und entscheidet, Ziel: Optionen so groß wie möglich. Rahmen der Kamera (`_frame_opening`) folgt dem neuen Rechteck.

## 2. Immer sichtbar, in den Tisch eingelassen
Die Fläche steht PERMANENT (nicht nur während einer Öffnung): leer zeigt sie einen ruhigen Leer-Zustand (z. B. „Paket im Lager anklicken zum Öffnen“, in der Runde „öffnen nach der Runde“), ohne Knöpfe. Sie ist eine flache VERTIEFUNG im Tisch — eine permanente Grube wie die Lager-Gruben (neuer `PIT_*`-Slot in `PERMANENT_PITS`, `MAX_PITS` in Skript UND beiden Shadern anheben, `PackPitView` ohne Kragen wie `PIT_SECTION`, geringe Tiefe), der Schirm der Fläche liegt auf ihrem Boden bzw. ihre Anzeige bleibt lesbar. Die unsichtbare LANDEFLÄCHE der Würfel-Physik (`_build_case_ground`) sitzt dann auf dem Grubenboden, ebenso Hüllen und Optionen. „Sichtbar heißt bedienbar“ gilt weiter; die Öffnung bleibt MODAL wie bisher.

## 3. Die Würfel springen nach RECHTS und bleiben liegen
Heute fallen die Würfel aus der Schatulle fast senkrecht, und einige verschwinden im Tisch (Landefläche deckt ihren Weg nicht oder sie starten unter ihr — Ursache finden, nicht verstecken). Neu: jeder Schuß geht nach Bild-RECHTS in die Fläche hinein (Impuls hauptsächlich Richtung Aufstellung, flacher Bogen, etwas Streuung), alle landen und BLEIBEN sichtbar auf dem Boden der Fläche (Boden und Wände der Landefläche decken die ganze Fläche; kein Würfel darf durch- oder herausfallen — Test bzw. Probe zählt am Ende der Show alle Körper innerhalb des Rechtecks), und erst wenn alle ruhen (oder `PACK_SETTLE_MAX` greift), gleiten ALLE ZUGLEICH auf ihre Plätze. Die Schatulle steht dazu am linken Rand der Fläche.

## 4. Die Würfel-Kacheln ausbalancieren
Jede Option ist eine Kachel (Rahmen) mit dem Würfel-Körper oben und darunter seiner Die-View (gewählte Seite + Netz). Heute: unten viel leerer Rand, und der Würfel überdeckt den oberen Rand der Die-View. Neu: Würfel und Die-View teilen die Kachel ausgewogen — der Würfel sitzt ganz über der Die-View (er projiziert an der geneigten Kamera nach oben/unten — wie `WorkshopView.BENCH_TILT_TRIM` gemessen kompensieren, nicht raten), die Die-View darunter, gleiche Luft oben und unten; die Kachelhöhe folgt dem Inhalt statt umgekehrt. Gilt sinngemäß auch für Karten- und Modul-Optionen.

## Docs und Tests
Root-`CLAUDE.md` (PAKET-AUSWAHL und Layout rechts: neue Maße, permanente Vertiefung, Wurf nach rechts), `scripts/ui/CLAUDE.md`, `scripts/table/CLAUDE.md`. Tests für das neue Rechteck (bündig mit Magazin-Unterkante, eine Fuge neben Werkstatt, keine Überlappung mit Werkstatt/Info/Magazin/Lager), Leer-Zustand, permanente Grube, Kachel-Maße (Würfel-Rect überlappt Die-View nicht, Rand unten ≈ oben).
