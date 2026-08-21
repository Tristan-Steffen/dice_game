---
name: asset-gen
description: Generate image assets for Fumble with the Gemini API via tools/imagegen.py — charm concept images for image-to-3D, engraving icons, mood boards. Use when the user asks for a generated image, concept art, a charm model reference, or an icon.
---

# Bild-Assets erzeugen

`tools/imagegen.py` ruft die Gemini-Bild-API. Voraussetzung: `pip install google-genai`
und `GEMINI_API_KEY` in der Umgebung. Das Skript schreibt die Datei und gibt ihren
Pfad auf stdout aus.

```bash
python tools/imagegen.py --out <ziel> --style <stil> --prompt "<motiv>" [--n 3] [--ref <bild>]
```

Stile liegen in `tools/styles/`: **charm** (Borderlands-Trinket, Dreiviertelansicht,
Vorlage für Bild→3D) und **engraving** (Monoline-Neon-Icon). Der Stiltext wird dem
Motiv vorangestellt — im `--prompt` steht nur das Motiv, nie der Stil.

## Die Schleife ist der Punkt

Ein Bild blind zu erzeugen bringt nichts. Immer:

1. `--n 3` erzeugen, in einen Scratch-Ordner, nicht direkt nach `assets/`.
2. Jede Datei mit dem Read-Tool **anschauen**.
3. Mechanisch prüfen: Silhouette eindeutig? Ein Objekt oder mehrere? Text im Bild
   (Generatoren schreiben kaputte Schrift — disqualifiziert das Bild)? Rand frei?
   Hintergrund neutral? Neonakzent genau einer?
4. Prompt nachschärfen, wiederholen. Erst der Gewinner wandert nach `assets/`.

Über Geschmack entscheidet der Nutzer, nicht das Modell — die obigen Punkte sind
prüfbar, „schön“ ist es nicht. Die Auswahl unter den brauchbaren Kandidaten vorlegen.

## Konventionen

- Dateiname = Content-id (`assets/models/<charm_id>.glb`,
  `assets/textures/engravings/<engraving_id>.jpg`) — siehe CLAUDE.md.
- Charm-Prompts stehen gesammelt in `assets/models/CHARM_PROMPTS.md`; ein neuer
  Prompt gehört dort hinein, ✔ markiert die fertigen.
- Ein Charm-Bild ist **Zwischenschritt**, kein Asset: es geht in Tripo (Bild→3D),
  das `.glb` ist das Ergebnis. Das Bild selbst nicht einchecken.
- Generierläufe nach `%TEMP%` o. ä., nie ins Repo — jede Datei unter `assets/`
  zieht in Godot eine `.import`-Datei nach sich.

## Kosten

Standardmodell ist `gemini-3.1-flash-lite-image` (~$0.034/Bild, nur 1K, keine
Stil-Referenzen). Läufe mit `--ref` brauchen `--model gemini-3.1-flash-image`
(dann `--size 512` nehmen, $0.045/Bild). Nie 2K/4K für Icons oder
Tripo-Vorlagen. Für Massenläufe (z. B. alle fehlenden Charm-Bilder) die
Batch API erwähnen: 50 % Rabatt, bis 24 h Wartezeit — lohnt ab ~50 Bildern,
ist aber nicht in imagegen.py verdrahtet.

## Grenzen

Das Skript deckelt sich selbst: `MAX_PER_CALL` 4, `MAX_PER_DAY` 120 (Zähler in
`tools/.imagegen_state.json`). Läuft das Budget voll, nicht umgehen — melden.
