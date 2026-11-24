# Plan: WETTEN, GLÜCK, ENERGIE, CHIPS als Bauteile — je drei Entwürfe (2026-11-24)

Ziel: so wenig 2D-Schirm wie möglich. Jede Station wird ein Bauteil der Platine, das man
auch ohne Text versteht. Diese Runde liefert NUR Blender-Entwürfe zur Wahl, keinen Spielcode.

## Gemeinsame Regeln

- **Medium**: je Station EIN Skript `tools/blender_<teil>_variants.py` nach dem Muster von
  `tools/blender_combo_bay_variants.py` (Helfer `blender_data_media` als `dm`,
  `blender_chip_screens` als `cs`). Achsen: X = Bild-rechts, Y = Bild-oben, Z = Höhe, Tisch Z = 0.
- **Ausgabe**: `E:/Generated Images/Fumble/<teil>_entwuerfe_2026-11-24/`, nie ins Repo.
  Je Variante `a_`/`b_`/`c_` plus: `*_schraeg.png` (Kamera wie die Station im Spiel, steil von
  oben, leicht von Bild-unten), `*_oben.png` (senkrecht), `*_detail.png`, `*_zustaende.png`.
  Dazu EIN `vergleich.png` mit allen dreien nebeneinander in derselben Kamera.
- **Look**: sauber-futuristisches Casino, Neon behaglich, edel. KEIN Retro: keine Nixie-Röhren,
  keine CRTs, keine Flip-Dots, keine Zeigerinstrumente. Erlaubt: Segment-Fenster, LED-Punkte,
  Lichtleiter, OLED-/E-Paper-Etiketten, gebürsteter Stahl, schwarzer Lack, Gold-Pads, Rauchglas.
- **Licht**: am Tisch beleuchtet nichts. Jedes Teil muß mit Eigenlicht lesen (Emission knapp
  unter der Bloom-Schwelle), der Stahl wie `chip_steel` mit festem Schlüssellicht.
- **Grund**: nachtgrüne Platine (Massefläche), Bezeichner im Bestückungsdruck (U5 WETTEN,
  U8 CHIPS, U9 GLÜCK, U10 ENERGIE), unten drei Züge zum Haupt-Bus mit Gold-Pads.
- **Text nur dort, wo echte Hardware eine Anzeige hat**: ein kleines Etikett-Display mit
  Einfassung und sichtbarem Anschluß ist ein Bauteil, ein Fenster nicht.
- **Maße bleiben**: Grundriß und Platz jeder Station sind gegeben (unten), EINE Größe je Ding
  (Chip, Karte, Würfel, Glückswürfel) gilt weiter.

## 1. WETTEN (heute `SideBetPanel` + drei Gruben)

**Gegeben**: Grundriß 10,36 breit × 15,20 hoch (Welt). Drei Plots untereinander, je 9,0 × 4,3.
Größter Körper im Plot 3,9 × 2,4 (Chip-Stapel/Elko-Feld), liegende Karte 1,5 × 2,3.
Je Wette zu zeigen: Bedingung (bis 60 Zeichen, drei Zeilen), Handel „Einsatz → Gewinn“,
Live-Stand, Zustand offen / auf Kurs (grün) / gescheitert (rot) / gewonnen.
Ablauf bleibt: Einsatz fliegt als Körper und wird geschluckt, der Gewinn wartet unten und
hebt sich bei Erfüllung. Alle Auskunft bleibt IN der Station (keine Anzeige an der Grube).

**Zustands-Blatt je Variante**: Angebot · gesetzt (Gewinn wartet) · erfüllt (Gewinn oben) · gescheitert.

- **A · LOGIKGATTER**: je Wette ein flaches Modul. Links der EINSATZ-SOCKEL (Mulde mit Federclips,
  der Chip-Stapel liegt darin), rechts die GEWINN-BUCHT unter einer Rauchglas-Klappe mit Riegel,
  dazwischen im Bestückungsdruck ein UND-Gatter. Zwei Eingangs-Züge (A = Einsatz, B = Bedingung)
  und ein Ausgang leuchten einzeln, sobald sie wahr sind. Die Bedingung steht auf einem
  schmalen E-Paper-Etikett über dem Gatter, der Handel als zwei kleine Segment-Felder an Sockel
  und Bucht. Gewonnen: Riegel fährt, Klappe schwenkt auf. Gescheitert: Ausgang rot, Bucht dunkel.
- **B · RELAIS-RIEGEL**: drei quer liegende Schaltmodule auf einer gemeinsamen Tragschiene.
  Jedes hat eine klare Haube, unter der man Anker und Kontakt sieht: offen = Kontakt getrennt,
  erfüllt = Anker zieht an, Kontakt schließt, Lichtbogen-Linie grün. Der Gewinn liegt in einer
  SCHUBLADE (Hot-Swap-Schacht) rechts, die bei Gewinn nach Bild-rechts ausfährt. Einsatz
  verschwindet durch einen Einwurf-Schlitz oben am Modul. Bedingung auf einem OLED-Streifen
  längs der Vorderkante, Zustand zusätzlich als mechanische Fahne (grün/rot) im Haubenfenster.
- **C · SICHERUNGSHALTER**: der Einsatz IST die Brücke. Zwischen zwei kräftigen Stahl-Klemmen
  sitzt eine Glaspatrone, in der die Einsatz-Chips stehen; sie schließt den Stromkreis zum
  TRESOR rechts (kleiner Stahlkasten mit Sichtfenster und rundem Schloßring, darin der Gewinn).
  Gescheitert: die Patrone brennt durch (dunkel, Riß im Leuchtfaden). Gewonnen: Schloßring
  dreht, Tresordeckel fährt zur Seite. Bedingung als Etikett-Display auf dem Tresordeckel,
  der Live-Stand als LED-Kette entlang der Patrone.

## 2. GLÜCK (heute `LuckStationView`, gold)

**Gegeben**: Grundriß 6,2 breit × 15,2 hoch. Glückswürfel Kante 1,53, schwebt über seinem Sitz.
Zu zeigen: die sechs Seiten mit echten Augen (1–6 je Seite, zuletzt gewürfelte gold gesäumt),
„Ø n,n Wahlen“, Glücks-Pegel bis zur nächsten Schwelle (Glück n · Auge bei m), Bonus-Zeile
(Freie Hand / Noch n Einbauten). Der Würfel fliegt für jede Öffnung fort und wieder heim.

**Zustands-Blatt**: Start (alle Seiten 1) · mittlerer Lauf (gemischt, Pegel halb, letzte Seite
markiert) · spät (mehrere Seiten 5–6, Bonus-Lampe an) · Würfel unterwegs (Sitz leer).

- **A · ABSCHIRMHAUBE (Zufallsgenerator)**: goldene HF-Abschirmhaube mit großem Fenster, darin
  der Sockel, über dem der Würfel schwebt. Darunter das aufgeklappte Kreuz als sechs Pad-Felder,
  jedes mit bis zu sechs versenkten Smaragd-LEDs als Augen; die letzte Seite trägt einen
  Goldrahmen. Pegel = LED-Balken mit Schwellen-Marke, Ø = kleines Segment-Fenster, Bonus = eine
  Meldelampe mit Druck „FREIE HAND“.
- **B · RESONATOR**: der Würfel schwebt in einem liegenden Glaszylinder zwischen zwei goldenen
  Elektroden-Kappen (ein Quarz unter Glas). Die sechs Seiten stehen als REIHE aus sechs kleinen
  Chips mit Augen-LEDs längs der Station (kein Kreuz), jeder mit Seitennummer im Druck. Der
  Pegel ist eine Säule aus Kondensator-Segmenten, die sich von unten füllt; an der Schwelle
  sitzt ein Gold-Kontakt. Ø und Bonus als zwei Lichtleiter-Fenster am Fuß.
- **C · NULLKRAFT-SOCKEL**: der Würfel sitzt über einem goldenen ZIF-Sockel mit Hebel (Hebel
  offen = Würfel unterwegs). Das Kreuz der Seiten ist EIN großer Chip mit sechs Fenstern. Der
  Pegel ist eine Bank aus DIP-Schaltern: je Glückspunkt kippt ein Schalter, die nächste Schwelle
  ist ein farbig abgesetzter Schalter. Ø als Segment-Fenster im Chip, Bonus als Steckbrücke,
  die leuchtet, wenn sie gesteckt ist.

## 3. ENERGIE (heute `EnergyBankView`, Akku-Bank)

**Gegeben**: Grundriß 6,2 breit × 15,0 hoch. Zehn Reihen zu je fünf Energie (Deckel wächst in
Fünferschritten bis 50), Anzeige „Stand / Deckel“. Gekaufte Kapazität kommt als Körper an.
Energie reist als Licht hinein und hinaus.

**Zustands-Blatt**: 0/5 · 3/5 · 12/15 · 50/50.

- **A · KONDENSATORBANK**: je freigeschalteter Reihe fünf stehende Becher-Kondensatoren zwischen
  zwei Kupfer-Stromschienen. Geladen leuchtet der Kopf (Ring und Kerbkreuz) cyan, leer ist er
  dunkles Aluminium. Gesperrte Reihen sind unbestückte Lötaugen mit Bestückungsdruck. Oben ein
  Segment-Modul „12/15“ mit Flachband-Anschluß.
- **B · SPANNUNGSWANDLER (Phasen)**: zehn Phasen nebeneinander, jede ein Paar aus Ringkern-Spule
  und Kühlkörper. In den Rippen jedes Kühlkörpers liegt ein Lichtbalken mit fünf Segmenten;
  gesperrte Phasen tragen eine Abdeckkappe. Der Stand steht als Segment-Fenster im Controller-
  Chip am Kopf, von dem zehn feine Züge zu den Phasen laufen.
- **C · KLINGEN-RACK**: zehn schmale Akku-Klingen stehen hochkant in einer Backplane mit
  Auswurf-Hebeln (wie Netzteil-Einschübe). Die Oberkante jeder Klinge trägt fünf Lichtfenster.
  Leere Schächte zeigen die goldene Kontaktleiste am Boden. Eine neue Klinge wird von oben
  eingesteckt und rastet. Stand als Segment-Modul auf der Backplane-Kopfleiste.

## 4. CHIPS (heute `ChipTrayView` in der Fassung `TreasureChestView`)

**Gegeben**: Grube 10,36 breit × 15,20 hoch, sieben Rinnen (1/5/25/100/500/2.500/10.000, die 1er
unten), 6° nach Bild-rechts geneigt, Chips hochkant, alles kommt links, alles geht rechts durch
Sperre und Wandschlitz. Rinne faßt 20, Übertrag in die nächste. Chipfarben aus `ChipStackView`
(neu Violett 500, Orange 2.500, Platin 10.000). Die Mechanik bleibt; ersetzt wird die gemalte
Fassung (Rinnen-Kopf mit Wert, Kometen-Schiene) und die Rinne bekommt ein Gesicht.

**Zustands-Blatt**: leer · $137 · $4.860 · eine Rinne im Übertrag (voll, Sperre offen).

- **A · SCHIEBEREGISTER**: Stahlrahmen, am Kopf jeder Rinne eine gravierte, hinterleuchtete
  Wert-Kappe in Chipfarbe. Der Einlauf ist eine Gabel-Lichtschranke, der Auslauf ein
  Hubmagnet-Riegel. Zwischen zwei Rinnen sitzt rechts je eine ÜBERTRAG-Lampe mit Pfeil nach oben.
  Links läuft eine Takt-Schiene mit sieben Abgängen.
- **B · BAUTEIL-FEEDER**: jede Rinne ist die Spur eines Gurt-Feeders aus der Bestückung:
  Transportlöcher längs, links ein Zahnrad mit Sichtfenster (dreht beim Einlauf), rechts die
  Abnahme-Klappe. Der Wert steht auf einem Etikett-Schild am Feeder-Kopf, Farbe = Chipfarbe.
  Übertrag = ein Greifer-Licht, das zur nächsten Spur springt.
- **C · SPEICHERBANK**: sieben lange Steckplätze mit weißen Riegel-Hebeln an beiden Enden, die
  Chips stehen darin wie Speicherzellen. Der rechte Hebel ist die Sperre (klappt auf, gibt
  frei), der linke rastet beim Einlauf. Wert als Prägung auf dem Steckplatz-Kragen, dazu eine
  Füllstands-Leiste aus vier LEDs je Steckplatz (5/10/15/20).

## Ablauf

1. Vier Opus-Agenten, einer je Station, jeder schreibt sein Skript und rendert seine Blätter.
2. Sichtung der Blätter, Spieler-Wahl je Station (Mischen von Merkmalen erlaubt).
3. Je gewählter Fassung eine eigene Umbau-Welle im Spiel (Körper in `table/`, das Fenster in
   `ui/` meldet nur noch Rechtecke).

## Welle 1: Umsetzung im Spiel (Spieler-Wahl 2026-11-24)

Gewählt: GLÜCK „C2 Nullkraft-Sockel“, ENERGIE „C2 Klingen-Rack“, CHIPS „A2 Schieberegister“.
Maßgeblich sind die Blender-Entwürfe (Maße, Teile, Zustände) und ihre Blätter in
`E:/Generated Images/Fumble/<glueck|energie|chips>_entwuerfe_2026-11-24/runde2/`:
`build_c2` in `tools/blender_luck_variants.py`, `var_c2`/`blade2` in
`tools/blender_energy_variants.py`, `variant_a` + `variant_a2` in `tools/blender_chip_tray_variants.py`.

Für alle drei: code-gebaut in `table/`, kein Szenenlicht nötig (Eigenlicht unter der Bloom-Schwelle,
Stahl wie `ChipFrameView`), Platz und Grundriß der Station bleiben, EIN idempotenter Schreiber je
Körper, Endzustand zuerst, ui/ faßt keinen Körper an. Kein neues Loch in der Anzeige.

### ENERGIE (zuerst, kleinste)
`EnergyBankView` wird das Klingen-Rack; die öffentliche Schnittstelle bleibt (`set_energy`, `fly_in`,
`pulse`, `riding`, `energy_count`, `cap_count`, `number_text`, `cap_text`, `segment`, `cell_stands`,
`sweeping`, `cell_spot`, `row_x`, `SIZE`), damit `scene_root` unverändert bleibt.
- Flacher Stahlkragen um einen dunklen Schacht, zehn Plätze mit Nummern 01–10 im Druck links.
- Je freigeschalteter Reihe eine KLINGE: nur ihre Oberkante steht über dem Tisch (≤ 0,45 eigene
  Einheiten), darauf fünf Lichtfenster (eine Energie je Fenster), rechts der schmale Hebel mit
  Lichtspitze: voll cyan, angebrochen bernstein, leer dunkel.
- Leerer Platz: goldene Kontaktleiste am Schachtboden.
- Neue Kapazität: die Klinge kommt in voller Höhe (Kontaktkamm unten) über ihrem Platz an und senkt
  sich hinein; ihr Platz ist bis dahin cyan umrandet. Der Flug vom Schwarzmarkt bleibt.
- Oben das Segment-Modul „Stand/Deckel“ (Label3D genügt, Schrift wie die Disketten) mit Flachband.

### GLÜCK
Neuer Körper `LuckStationBody` (table/); `LuckStationView` malt nichts mehr und MELDET nur noch
(`seat_px`, dazu die Rechtecke der Teile); die reinen Text-Regeln (`expected_text`, `gauge_share`,
`bonus_text` …) bleiben dort. Das Fenster fällt aus den `window_*`-Uniformen, sein Feld wird dem
Deck als ruhiges Feld gemeldet.
- SOCKEL: goldener Rahmen, Kontakte nur im Randband, in der Mitte der ruhige Sitz mit Lichtring
  (grün = Würfel da, bernstein = unterwegs). Der Sitz ist der bestehende `luck_seat_px`.
- HEBEL rechts mit Knauf: verriegelt liegt er an der Flanke (Knauf grün), ist der Würfel unterwegs
  (`_luck_at` ≠ HOME), steht er auf (Knauf bernstein). Fahrt per Tween, Endzustand zuerst.
- Sechs Abtast-Züge vom Sockel in den CHIP mit sechs Fenstern im Kreuz (`LuckDie.NET_LAYOUT`),
  echte Augen als LEDs (`LuckDie.pip_layout`), die Seite des letzten Wurfs gold gesäumt, im Chip
  das Segment-Fenster „Ø n,n“. Ein Schlag (`pip_changed`) läßt das neue Auge aufblitzen.
- PEGEL in einer Zeile: Glück · Schalterbank (zehn Schalter, der letzte gold = Schwelle, gekippt
  nach `gauge_share`) · nächste Schwelle.
- Zwei STECKBRÜCKEN: „FREIE HAND“ und „EINBAU“ mit Zahl; ungesteckt nur die blanken Stifte.
- `set_state(faces, last_face, state)` ist der EINE Schreiber und schreibt nur den Wechsel.

### CHIPS
Neuer Körper `ChipTrayDress` (table/) um die unveränderte Grube und `ChipTrayView`; die gemalte
Fassung (Rinnen-Kopf, Kometen-Schiene) malt nichts mehr und meldet nur noch ihre Punkte
(`pit_rect`, `entry_px`, `exit_px`, `rail_x`). Mechanik, Belegung und Übergänge bleiben.
- Stahlrahmen um die Grube, links je Rinne eine hinterleuchtete WERT-KAPPE in Chipfarbe
  (`ChipStackView.value_label`), an der 10K-Kappe „×n“ ab dem sechsten.
- Takt-Schiene links mit sieben Abgängen; sie ist der Weg der Geld-Kometen an den Rinnen-Kopf.
- Einlauf: Gabel-Lichtschranke je Rinne, ihr Strahl blitzt bei `chip_entered`.
- Auslauf: Hubmagnet je Rinne mit Statusring (ruht schwach weiß, bernstein solange die Sperre
  offen ist, `chip_left`).
- FÜLLMARKEN bei 5/10/15/20 auf dem Steg neben jeder Rinne: erreicht leuchten sie in Chipfarbe,
  die 20 wird bernstein, wenn die Rinne voll ist.
- ÜBERTRAG: bernsteinfarbener Lichtweg samt Pfeil auf der Takt-Schiene von Kappe r zu r + 1 für
  die Dauer eines `carry`-Schritts (beim Borgen umgekehrt), dazu die Übertrag-Lampe rechts.
- Die bisherigen Blitze der Fassung (Gewinn, Zahlung) gehen auf Kappe und Statusring über.

### Abnahme
Je Station eine Sichtprobe im Spiel (Übersicht und Station CHIPS, 1280 × 720) nach
`E:/Generated Images/Fumble/<station>_spiel_2026-11-24/`, Tests angepaßt bzw. neu, die Suite
einmal am Ende, ein Boot, die Ordner-CLAUDE.md nachgezogen (kurz).
