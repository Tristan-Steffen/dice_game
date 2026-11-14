# -*- coding: utf-8 -*-
"""Soundeffekt-Generator für Fumble über die ElevenLabs-API (Text to Sound Effects).

Varianten je Aufruf, Pfade auf stdout - der Aufrufer hört sie an und wählt den
Gewinner, der allein nach assets/sfx/ kopiert wird. Stilvorgaben stehen in
tools/styles/<name>.txt und werden dem Prompt vorangestellt.

    setx ELEVENLABS_API_KEY "..."   # einmalig, dann Shell neu öffnen

    python tools/sfxgen.py --out score/tick.wav --style sfx --prompt "..." --n 4 --duration 0.4
    python tools/sfxgen.py --out case/rattle.wav --prompt "..." --dry-run

Relative --out-Pfade landen unter GEN_DIR, nie im Repo. Nur Standardbibliothek.
"""
import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

STYLE_DIR = Path(__file__).resolve().parent / "styles"
STATE_FILE = Path(__file__).resolve().parent / ".sfxgen_state.json"
GEN_DIR = Path("E:/Generated Audio/Fumble")

ENDPOINT = "https://api.elevenlabs.io/v1/sound-generation"
DEFAULT_MODEL = "eleven_text_to_sound_v3"
# WAV unter 44,1 kHz geht auf jedem bezahlten Plan; 44,1/48 kHz verlangt evtl. Pro.
DEFAULT_FORMAT = "wav_48000"
FALLBACK_FORMATS = ["wav_32000", "mp3_44100_128"]

# Kostenbremse: harte Grenzen im Skript. Credits nach Doku 40/s mit Dauer,
# sonst laut Preisseite ~200 je Erzeugung - geschätzt wird mit dem Höheren.
MAX_PER_CALL = 8
MAX_CREDITS_PER_DAY = 30000
CREDITS_PER_SECOND = 40
CREDITS_AUTO = 200


def _load_state() -> dict:
    if not STATE_FILE.exists():
        return {}
    try:
        return json.loads(STATE_FILE.read_text(encoding="utf-8"))
    except (ValueError, OSError):
        return {}


def _spent_today(state: dict) -> int:
    return int(state.get("credits", 0)) if state.get("day") == time.strftime("%Y-%m-%d") else 0


def _book(state: dict, credits: int) -> None:
    state["credits"] = _spent_today(state) + credits
    state["day"] = time.strftime("%Y-%m-%d")
    try:
        STATE_FILE.write_text(json.dumps(state), encoding="utf-8")
    except OSError:
        pass


def _estimate(duration) -> int:
    if duration is None:
        return CREDITS_AUTO
    return max(CREDITS_AUTO, int(round(duration * CREDITS_PER_SECOND)))


def _style_text(name: str) -> str:
    path = STYLE_DIR / (name + ".txt")
    if not path.exists():
        known = sorted(p.stem for p in STYLE_DIR.glob("*.txt"))
        sys.exit("Unbekannter Stil %r. Vorhanden: %s" % (name, ", ".join(known) or "-"))
    return path.read_text(encoding="utf-8").strip()


def _request(key: str, body: dict, fmt: str) -> bytes:
    url = "%s?output_format=%s" % (ENDPOINT, fmt)
    req = urllib.request.Request(url, data=json.dumps(body).encode("utf-8"), method="POST",
                                 headers={"xi-api-key": key, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        return resp.read()


def _ext_for(fmt: str) -> str:
    return ".mp3" if fmt.startswith("mp3") else ".wav"


def main() -> None:
    ap = argparse.ArgumentParser(description="ElevenLabs-Soundeffekte für Fumble")
    ap.add_argument("--out", required=True, help="Zieldatei; relativ = unter %s; bei --n>1 _1.._n" % GEN_DIR)
    group = ap.add_mutually_exclusive_group(required=True)
    group.add_argument("--prompt", help="Klangbeschreibung (Englisch trifft besser)")
    group.add_argument("--prompt-file", help="Datei mit der Klangbeschreibung")
    ap.add_argument("--style", help="Stil-Präfix aus tools/styles/<name>.txt")
    ap.add_argument("--n", type=int, default=4, help="Varianten (max %d)" % MAX_PER_CALL)
    ap.add_argument("--duration", type=float, help="Sekunden, 0.5-30; ohne = die API schätzt")
    ap.add_argument("--influence", type=float, default=0.5,
                    help="Prompt-Einfluss 0-1 (hoch = wörtlicher, weniger Streuung)")
    ap.add_argument("--loop", action="store_true",
                    help="Nahtlose Schleife - kommt laut Doku nur als MP3, das in Godot eine Lücke reißt")
    ap.add_argument("--format", default=DEFAULT_FORMAT, help="output_format der API")
    ap.add_argument("--model", default=DEFAULT_MODEL)
    ap.add_argument("--dry-run", action="store_true", help="Nur Prompt und Kostenschätzung zeigen")
    args = ap.parse_args()

    if not 1 <= args.n <= MAX_PER_CALL:
        sys.exit("--n muss zwischen 1 und %d liegen." % MAX_PER_CALL)
    if args.duration is not None and not 0.5 <= args.duration <= 30.0:
        sys.exit("--duration muss zwischen 0.5 und 30 liegen.")
    if not 0.0 <= args.influence <= 1.0:
        sys.exit("--influence muss zwischen 0 und 1 liegen.")

    motif = Path(args.prompt_file).read_text(encoding="utf-8").strip() if args.prompt_file else args.prompt
    prompt = "%s %s" % (_style_text(args.style), motif) if args.style else motif
    fmt = args.format
    if args.loop and not fmt.startswith("mp3"):
        print("# --loop: WAV gibt es nur ohne Schleife, nehme mp3_44100_128", file=sys.stderr)
        fmt = "mp3_44100_128"
    cost = _estimate(args.duration) * args.n

    if args.dry_run:
        print(prompt)
        print("# %d Variante(n), Format %s, Modell %s, geschätzt %d Credits"
              % (args.n, fmt, args.model, cost), file=sys.stderr)
        return

    state = _load_state()
    spent = _spent_today(state)
    if spent + cost > MAX_CREDITS_PER_DAY:
        sys.exit("Tagesbudget erschöpft (%d + %d > %d Credits). Grenze steht in sfxgen.py."
                 % (spent, cost, MAX_CREDITS_PER_DAY))
    key = os.environ.get("ELEVENLABS_API_KEY")
    if not key:
        sys.exit("ELEVENLABS_API_KEY ist nicht gesetzt.")

    body = {"text": prompt, "model_id": args.model, "prompt_influence": args.influence,
            "loop": args.loop}
    if args.duration is not None:
        body["duration_seconds"] = args.duration

    out = Path(args.out)
    if not out.is_absolute():
        out = GEN_DIR / out
    out.parent.mkdir(parents=True, exist_ok=True)
    (out.parent / (out.stem + "_prompt.txt")).write_text(
        "%s\n\n# n=%d duration=%s influence=%s loop=%s model=%s\n"
        % (prompt, args.n, args.duration, args.influence, args.loop, args.model), encoding="utf-8")

    formats = [fmt] + ([f for f in FALLBACK_FORMATS if f != fmt] if fmt == DEFAULT_FORMAT else [])
    per_take = _estimate(args.duration)
    for index in range(args.n):
        while True:
            try:
                blob = _request(key, body, formats[0])
                break
            except urllib.error.HTTPError as err:
                detail = err.read().decode("utf-8", "replace")[:400]
                # Ein Format, das der Plan nicht hergibt, fällt eine Stufe tiefer.
                if err.code in (400, 401, 403, 422) and len(formats) > 1 and "format" in detail.lower():
                    print("# %s abgelehnt (%d), versuche %s" % (formats[0], err.code, formats[1]),
                          file=sys.stderr)
                    formats.pop(0)
                    continue
                sys.exit("API-Fehler %d: %s" % (err.code, detail))
            except urllib.error.URLError as err:
                sys.exit("Netzwerkfehler: %s" % err.reason)
        stem = out.stem if args.n == 1 else "%s_%d" % (out.stem, index + 1)
        target = out.with_name(stem + _ext_for(formats[0]))
        target.write_bytes(blob)
        _book(state, per_take)
        print(target)

    print("# %d Variante(n) in %s, heute ~%d/%d Credits (geschätzt)"
          % (args.n, formats[0], _spent_today(state), MAX_CREDITS_PER_DAY), file=sys.stderr)


if __name__ == "__main__":
    main()
