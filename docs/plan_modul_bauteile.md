# Plan: Die Module als Bauteile auf der Signalleitung

Stand 2026-11-21, GEBAUT in Welle B (siehe *Stand Welle B* unten). Grundlage: die Entwurfsrunden in
`tools/blender_combo_module_variants.py` (Sichtproben `E:/Generated Images/Fumble/kombinationen_module_*`).

## Die Idee

Das Ergebnis einer Kombination verläßt den Chip als Signal auf EINER Leitung. Jedes Modul ist ein
Bauteil AUF dieser Leitung, und seine Form sagt, was es mit dem Signal tut. Der Text (Wert, Name)
bleibt als kleine Zeile am Bauteil, erklärt aber nichts mehr allein.

**Layout: L, das RACK** (Spieler-Entscheid 2026-11-21): zwei Spalten statt drei, je Kombination ein
Einschub mit dem Chip links und drei Plätzen rechts (je etwa 0,6 × 0,9 Chipbreiten). Die Leitung
läuft auf halber Höhe durch die Plätze.

Hüllmaß JEDES Moduls: **0,5 breit × 0,4 tief**, längs der Leitung. Der Rest des Platzes bleibt für
Zustandsanzeige und die kleine Wertzeile. Blockmodelle aller 26: `m_bauteile_oben`/`_unten` in
`tools/blender_combo_module_variants.py`.

## Regeln für alle

1. **Die FAMILIE sagt die Silhouette.** Wer die Familie erkennt, kennt die Art der Wirkung, bevor er
   das einzelne Teil kennt (Tabelle unten).
2. **Die FARBE bleibt die der Modulart** (`ComboPart.tint()`): Punkte Cyan, Mult Gold, Würfel Grün,
   ×-Teile Violett, Ökonomie Geldgrün, Brücken Pink. Nur das Licht trägt sie, der Körper ist Stahl,
   Keramik, Kupfer oder Glas.
3. **Was zählt, ZEIGT seinen Stand.** Zählwerk, Fehlerspeicher, Schwingkreis, Reihenklemme,
   Anlasser, Nachbrenner und Thermistor tragen ihren Zustand am Körper.
4. **Die Leitung danach zeigt die Wirkung**: dicker nach Punkten, heller nach Mult, doppelt nach
   einer zusätzlichen Auslösung.
5. **Die Seltenheit ist die Höhe** (bestehende Regel: 0,10 / 0,15 / 0,20 / 0,25) und die Tönung der
   Grundplatte. Keine Seltenheits-Akzente am Teil.
6. Von oben bei etwa 30 Bildschirm-px erkennbar; keine zwei Teile mit demselben Umriß.

## Die Familien

| Familie | Phase | Silhouette von oben | Bild |
|---|---|---|---|
| Speicher | Punkte | liegende Walze quer zur Leitung | Ladung wird dazugelegt |
| Wandler | Mult (+) | stehende runde Dose | Spannung wird hochgesetzt |
| Kontakte | Würfel | Reihe gleicher kleiner Teile, eines je Würfel | jeder Würfel berührt einen Kontakt |
| Röhren | Mult (×) | Glaskolben mit Glut, die größten Teile | das Signal wird vervielfacht |
| Abgriffe | Ökonomie | Schlitz oder Schleifer neben der Leitung | etwas wird abgezweigt |
| Brücken | Verbindung | Bogen, der den Platz verläßt | das Signal geht woanders hin |
| Fassungen | ohne Phase | Rahmen statt Bauteil | verändert den Chip, nicht das Signal |

## Die 26 Module

### Speicher - Punkte (Cyan)

| Modul | Wirkung | Bauteil | Was die Wirkung zeigt |
|---|---|---|---|
| Widerstand | +15 Punkte | Ein Keramikzylinder, liegend, drei Farbringe | Die Ringe sind sein Wert; die Leitung dahinter ist dicker |
| Spule | +8 Punkte, +1 Mult | Kupferwicklung auf Ferritkern, liegend | Zwei Farben: Kern cyan, Wicklung gold - beide Wirkungen |
| Vorwiderstand | +4 Punkte je Würfel-Auslösung | Kamm aus sechs kleinen Widerständen (Widerstandsnetzwerk) | Ein Zinken je Würfel; beim Auslösen blitzt der Zinken des Würfels |
| Reihenklemme | +5 Punkte, +1 Mult je Modul auf dem Chip | Klemmleiste mit drei Schraubklemmen | So viele Klemmen leuchten, wie Module stecken |

### Wandler - Mult, flach (Gold)

| Modul | Wirkung | Bauteil | Was die Wirkung zeigt |
|---|---|---|---|
| Kondensator | +3 Mult | Stehender Becher, Kreuzkerbe im Deckel | Der Deckel glüht; entlädt sich sichtbar bei der Wertung |
| Lötpunkt | +1 Mult je Würfel-Auslösung | Leiste mit sechs blanken Zinnkuppen | Eine Kuppe je Würfel, sie glüht beim Auslösen auf |
| Thermistor | +2 Mult je Ladung der Würfel | Flache Scheibe auf zwei Beinen | Ihr Rand trägt die Glühfarben der Ladung: Weiß, Gelb, Orange, Rot - er färbt sich mit der Ladung der Hand |
| Zählwerk | +1 Mult, wächst je Wertung | Rollenzählwerk mit drei Ziffernrollen | Die Rollen zeigen den aktuellen Wert und schalten sichtbar weiter |
| Fehlerspeicher | +1 Mult je Fumble des Blocks | Speicherbaustein mit Quarzfenster, darunter eine Reihe roter Fehlerlampen | Je Fumble eine Lampe |
| Anlasser | +6 Mult in der ersten Hand | Großer runder Startknopf mit Leuchtring | Leuchtet bis zur ersten Hand, danach dunkel und eingedrückt |

### Kontakte - Würfel (Grün)

| Modul | Wirkung | Bauteil | Was die Wirkung zeigt |
|---|---|---|---|
| Relais | Erster Würfel +1 Auslösung | Spule mit Schaltzunge, die nach LINKS zeigt | Die Zunge schlägt zweimal an; die Leitung macht eine Schleife am linken Ende |
| Endstufe | Letzter Würfel +1 Auslösung | Ovales Transistorgehäuse (zwei Schrauben) auf Kühlblech, Marke RECHTS | Spiegelbild des Relais: die Schleife sitzt am rechten Ende |
| Nebenschluss | Auch Würfel außerhalb zählen | Dicke Kupferschiene, die im Bogen UM die Leitung herumführt | Ein zweiter Weg: die Schiene sammelt, was an der Kombination vorbeigeht |
| Parallelschaltung | Jeder Würfel +1 Auslösung | Die Leitung teilt sich in zwei Schienen mit Sprossen und läuft wieder zusammen | Alles läuft doppelt; die Leitung dahinter bleibt doppelt |

### Röhren - Mult, vervielfachend (Violett, nur Schwarzmarkt)

| Modul | Wirkung | Bauteil | Was die Wirkung zeigt |
|---|---|---|---|
| Verstärkerröhre | ×1,5 Mult | Kleine liegende Glasröhre mit Gitter | Die Leitung tritt dünn ein und heller aus |
| Hochspannungsröhre | ×2 Mult | Große Röhre mit Anodenkappe und Koronaring | Größer und heller als die Verstärkerröhre; Überschläge am Ring |
| Magnetron | ×3 Mult, lädt die Würfel +1 | Runder Kupferblock mit Hohlraum-Rosette zwischen zwei Magneten | Die Rosette ist von oben unverwechselbar; bei der Wertung laufen Ringe hinaus zu den Würfeln |
| Schwingkreis | ×1,1 Mult, wächst je Wertung | Spule und Kondensator als Paar, darum ein Ring | Der Ring füllt sich mit dem Wachstum |
| Nachbrenner | ×2 Mult nach einem Fumble | Düse mit Blendenlamellen | Dunkel und geschlossen; nach einem Fumble offen mit Flamme (scharf) |

### Abgriffe - Ökonomie

| Modul | Wirkung | Bauteil | Was die Wirkung zeigt |
|---|---|---|---|
| Münzprüfer | +$2 je Wertung | Münzschlitz, eine Münze steckt halb darin | Bei der Wertung fällt sie durch |
| Stromabnehmer | +1 ⚡ je Wertung | Gefederter Schleifer (Scherenbügel) auf der Leitung | Er greift Strom von der Leitung ab; Funke am Kontakt |

### Brücken - Verbindung (Pink, nur Schwarzmarkt)

| Modul | Wirkung | Bauteil | Was die Wirkung zeigt |
|---|---|---|---|
| Querbrücke | Aktiviert die Kombination rechts | Bogen aus Flachband, der den Platz nach RECHTS verläßt | Er endet sichtbar am Nachbarn |
| Längsbrücke | Aktiviert die Kombination darunter | Derselbe Bogen nach UNTEN | wie oben |
| Kopplung | Kopiert das stärkste Kombi-Modul links | Zwei Spulen, die sich über einen Spalt ansehen; die linke hängt an einem Band vom linken Nachbarn | Über der rechten Spule steht das kopierte Modul als blasses Abbild |

### Fassungen - ohne Phase

| Modul | Wirkung | Bauteil | Was die Wirkung zeigt |
|---|---|---|---|
| Sperrdiode | Chip kann nicht gedrosselt werden | Schwarzer Zylinder mit einem Silberring, darunter das Schaltzeichen Dreieck-Strich | Sie läßt nur eine Richtung durch: die Drossel prallt sichtbar ab |
| Erweiterungsplatine | Belegt einen Platz, gibt zwei | Kleine Tochterplatine, die den Platz in zwei halbe teilt | Die Leitung läuft durch beide |

## Offene Punkte

- **Nachbarschaft im Rack (L):** Querbrücke, Längsbrücke und Kopplung reden von „rechts“, „darunter“
  und „links“. Bei zwei Spalten hat nur jede zweite Kombination einen rechten bzw. linken Nachbarn.
  Entweder die Regel ändert sich (z. B. „die nächste Kombination“) oder das Layout bleibt dreispaltig.
- **Reihenfolge:** auf EINER Leitung liegt nahe, daß die Reihenfolge der Module zählt. Heute zählt
  sie nicht (`ComboPartEffects` rechnet nach Phase). Entscheid nötig.
- **Erweiterungsplatine:** halbe Plätze heißen halbe Bauteile. Entweder schrumpfen Module darauf,
  oder die Platine wächst aus dem Platz heraus.
- **Gatter:** bisher nur als Entwurf (Runde 3). Sie wären eine eigene, achte Familie mit Fühlern.
- **Aufwand:** 26 Modelle neu in `tools/blender_part_models.py`; sieben davon mit Zustand am Körper.

## Stand Welle B (2026-11-21)

Gebaut auf dem GROSSEN CHIP (Welle A, `docs/plan_kombi_grosschip.md`), nicht im Rack L: 25 Bauteile
neu in `tools/blender_part_models.py` (`part_<id>.glb`), die Erweiterungsplatine bleibt code-gebaut.
Hüllmaß 1,4 längs × 1,3 quer auf der Platte 1,5 × 1,9; die Höhen-Leiter ist verdoppelt (0,2 / 0,3 /
0,4 / 0,5), weil 0,10 auf der großen Platte flach las. Zustand und Punktreihe setzt Godot
(`ComboPartBody.set_state`). Abweichungen: die Reihenklemme hat FÜNF Klemmen (bis zu fünf Module
auf einem Chip mit Platine), der Nebenschluss zeigt die übrigen Würfel bis sechs als Ringe, die
Hochspannungsröhre steht (Kreis von oben) statt zu liegen, damit sie sich von der Verstärkerröhre
abhebt; die Brücken enden mit ihrem Pfeil an der Plattenkante, nicht darüber hinaus. Sichtproben:
`E:/Generated Images/Fumble/kombi_module_spiel/`.
