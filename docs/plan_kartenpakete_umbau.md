# Karten-Pakete: Kartenzahl statt Größe, Güte wie die Würfel-Pakete (2026-11-15)

Spieler-Entscheid 2026-11-15 (Vorschlag aus der Session, „Richtung von Fable“).

## Inhalt
- **Sorte** bleibt: Zahlen / Material / Runen / Misch. Kein eigenes Multiplikator-Paket, kein Sonder-Paket.
- **Kartenzahl** ersetzt die Größe: 3er / 4er / 5er = `CardPack.SIZE_SMALL..SIZE_LARGE`
  (Optionen 3/4/5, Wahlen 1/1/2, Glückswurf wie bisher). Riesig fällt für Karten-Pakete weg;
  die geteilte Wahl-Tabelle bleibt für Modul-Pakete unverändert.
- **Güte** neu, dieselbe wie bei Würfel-Paketen (`DicePack.QUALITY_*`, Namen, Glück +0/+6/+12,
  Laden-Gewichte `DicePack.shop_quality_weights`):

  | Güte | Kartengrößen S/G/K | Garantie | Hauptgewinn |
  |---|---|---|---|
  | Standard | 70/25/5 | – | – |
  | Edel | 45/40/15 | eine Große | – |
  | Royal | 20/45/35 | eine Kolossale | 3 % (+0,25 je Glück) |

  Großauftrag hebt jede Güte eine Stufe (Royal: 10/40/50).
- **Preis** gerechnet: erwartete Wahlen × Optionswert(Sorte, Güte) × Prämie
  (`CHOICE_PREMIUM` + 0,05 je Option über drei).
- Name: „4er Zahlen-Paket · Edel“; Auskunft nennt Inhalt, Wahlen, Garantie und Glück.
- Nebenwette: das teuerste bezahlbare Paar aus Kartenzahl und Güte (wie `reward_dice_pair`).

## Optik (Kassette)
- **Güte = Metall des Gehäuses**, exakt die Schatullen-Metalle (`CASE_ALBEDOS` …), Oberfläche
  gebürstet statt Clous de Paris (`tools/gen_case_texture.py brushed`).
- **Sorte = Etikett mit Symbol** in der Sortenfarbe (Plus, Kacheln, Rune, drei Punkte für Misch), dazu Naht und Saum.
- **Kartenzahl = große weiße Ziffer** auf schwarzer Platte, auf Deckel und Rücken (Idee A, nachgezogen am selben Tag; Fenster und Rückenbalken sind gestorben).
- **Eine Dicke** für jede Kassette; Material- und Runen-Würfelpakete tragen dieselben Farben wie die Karten-Pakete (Pink, Gelb), Symbole Sechseck und Dreieck im Ring auf beiden.
- Stahlband, Stahlrahmen und Goldecken sterben (Gold heißt nur noch Royal), die Kontakte werden Stahl.

## Gestalt (Spieler-Wahl, später am 2026-11-15; seit dem 2026-11-16 überholt, siehe unten)
Etikett, Symbol und Ziffer sind gestorben. Die Kassette ist eine Hülle aus Blender
(`tools/blender_card_cassette.py` → `assets/models/hardware/card_cassette.glb`): zwei Platten und
eine Wand mit großen Fenstern im Güte-Metall, im Deckel ein klares Fenster. Darin liegen echte
Data-Cards als Treppe - eine je Option, in der Sorte des Pakets, die Größe nach der Güte, und
ihre Netze wechseln ständig (Vorrat je Sorte und Größe). Entwürfe:
`tools/blender_card_cassette_concepts.py`, `_led.py`, `_glass.py`.
Liegend bilden die Karten die Treppe unter dem Deckelfenster, stehend (im Lager) ein bündiger
Stapel, dessen Kanten man durch das Kopffenster zählt - die Lage der Kassette blendet zwischen beiden. Die Kassette ist so dick
wie die Schatulle, alle Fenster tragen getöntes Glas.

## Gestalt (Spieler-Wahl 2026-11-16): die Pappschachtel
Die Kassette ist gestorben. Das Karten-Paket ist eine bedruckte Pappschachtel wie die eines
RAM-Riegels, Entwurf "Retail" aus `tools/blender_card_box.py` (Export
`tools/blender_card_box_export.py` → `assets/models/hardware/card_box.glb`): Euro-Lasche am Kopf,
schräges Sortenband am Fuß, die Güte als Prägefolie (weiß, Silber, Gold), die Kartenzahl als
Augen auf Front und Kopf. Durch das Fenster (gut halb so lang wie die Schachtel) sieht man die
echten Karten - fast so groß wie die Schachtel, also nie alle ganz; so liest es als Fenster,
nicht als Bild. Die Treppe bleibt in jeder Lage, der Lager-Stapel ist gestorben, die Netze
wechseln nur unter dem Griff und auf dem Weg zur Öffnung.
