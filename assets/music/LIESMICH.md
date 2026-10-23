# Musik-Stems

Hier liegen die vier Schichten des Themas. Fehlt eine Datei, synthetisiert
`scripts/table/music_director.gd` einen Platzhalter — es läuft also auch leer.

## Dateinamen (fest, eine Datei je Schicht)

| Datei       | Inhalt                          |
|-------------|---------------------------------|
| `pad.ogg`   | Flächen, Textur                 |
| `bass.ogg`  | Bass                            |
| `keys.ogg`  | Melodie, Akkorde, Arpeggio      |
| `drums.ogg` | Schlagzeug, Percussion          |

`.wav` wird auch gelesen, `.ogg` gewinnt. **MP3 nicht** — der Encoder hängt vorn
und hinten Stille an, und die hört man bei jedem Schleifendurchlauf als Lücke.

## Was ein Stem erfüllen muß

- **Gleich lang wie alle anderen.** Jede Schicht läuft als eigener Player; nur
  gleich lange Schleifen bleiben über Stunden synchron. Ein Vielfaches von
  `MusicDirector.BAR_TIME` (2,0 s bei 120 BPM), also z. B. 8, 16 oder 32 s.
- **Naht- und fadenlos geschnitten** — kein Ausblenden am Ende, kein Intro.
- **120 BPM, G-Moll-Pentatonik.** `ScoreAudio.LADDER` sitzt auf G: in derselben
  Tonart spielt das Punkte-Hochzählen Melodie über dem Track statt daneben.
- **Kopfraum lassen**, Spitzen um −6 dBFS. Darüber liegen noch Würfel und
  Wertung, und der `Music`-Bus duckt per Sidechain ohnehin unter dem `Score`-Bus.
- **Mono oder Stereo**, aber alle vier gleich abgetastet (44,1 kHz).

## Brief für einen Komponisten

Ein Thema, vier Stems, 120 BPM, G-Moll-Pentatonik, seamless Loop. Genre:
synth-funk / „cozy cyberpunk" — Referenzen: *Citizen Sleeper*, Com Truise,
*Cloudpunk*, French Touch. Kein Retro-80s, kein CRT-Kitsch (siehe die
Art-Direction des Projekts). Die Schichten werden im Spiel einzeln ein- und
ausgeblendet, jede muß also für sich stehen und mit jeder Teilmenge der anderen
zusammen funktionieren.

Lizenz je Asset in einer `LICENSE.txt` daneben ablegen.
