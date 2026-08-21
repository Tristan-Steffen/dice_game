# -*- coding: utf-8 -*-
"""Bildgenerator für Fumble-Assets über die Gemini-API (Nano Banana).

Eine Datei je Aufruf, Pfad auf stdout - damit der Aufrufer das Ergebnis
zurücklesen und den Prompt nachschärfen kann. Stilvorgaben stehen in
tools/styles/<name>.txt und werden dem Prompt vorangestellt, damit die
Konvention nicht bei jedem Aufruf neu getippt wird.

    pip install google-genai
    setx GEMINI_API_KEY "..."      # einmalig, dann Shell neu öffnen

    python tools/imagegen.py --out foo.png --style engraving --prompt "..."
    python tools/imagegen.py --out foo.png --prompt "..." --ref alt.png --n 3
"""
import argparse
import base64
import json
import os
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STYLE_DIR = Path(__file__).resolve().parent / "styles"
STATE_FILE = Path(__file__).resolve().parent / ".imagegen_state.json"

# Lite ist das billigste Bildmodell ($0.034/Bild, nur 1K, keine Stil-Refs).
# Fuer Laeufe mit Referenzbildern --model gemini-3.1-flash-image (512er: $0.045).
DEFAULT_MODEL = "gemini-3.1-flash-lite-image"

# Kostenbremse: eine unbeaufsichtigte Schleife soll nicht durchdrehen. Beides
# sind harte Grenzen im Skript, nicht im Prompt - ein Prompt-Limit hält nicht.
MAX_PER_CALL = 4
MAX_PER_DAY = 120


def _load_state() -> dict:
    if not STATE_FILE.exists():
        return {}
    try:
        return json.loads(STATE_FILE.read_text(encoding="utf-8"))
    except (ValueError, OSError):
        return {}


def _spent_today(state: dict) -> int:
    day = time.strftime("%Y-%m-%d")
    return int(state.get("count", 0)) if state.get("day") == day else 0


def _book(state: dict, images: int) -> None:
    day = time.strftime("%Y-%m-%d")
    state["count"] = _spent_today(state) + images
    state["day"] = day
    try:
        STATE_FILE.write_text(json.dumps(state), encoding="utf-8")
    except OSError:
        pass


def _style_text(name: str) -> str:
    path = STYLE_DIR / (name + ".txt")
    if not path.exists():
        known = sorted(p.stem for p in STYLE_DIR.glob("*.txt"))
        sys.exit("Unbekannter Stil %r. Vorhanden: %s" % (name, ", ".join(known) or "-"))
    return path.read_text(encoding="utf-8").strip()


def _ref_part(path: Path) -> dict:
    mime = "image/png" if path.suffix.lower() == ".png" else "image/jpeg"
    return {
        "type": "image",
        "data": base64.b64encode(path.read_bytes()).decode("ascii"),
        "mime_type": mime,
    }


def _extract_image(interaction) -> bytes:
    """Bilddaten aus der Antwort - beide SDK-Formen, damit ein Versions-
    sprung nicht sofort alles bricht."""
    out = getattr(interaction, "output_image", None)
    if out is not None and getattr(out, "data", None):
        return base64.b64decode(out.data)
    for candidate in getattr(interaction, "candidates", []) or []:
        parts = getattr(getattr(candidate, "content", None), "parts", []) or []
        for part in parts:
            inline = getattr(part, "inline_data", None)
            if inline is not None and getattr(inline, "data", None):
                blob = inline.data
                return blob if isinstance(blob, bytes) else base64.b64decode(blob)
    raise RuntimeError("Antwort enthielt kein Bild (Filter? Prompt zu vage?)")


def main() -> None:
    ap = argparse.ArgumentParser(description="Gemini-Bildgenerator für Fumble-Assets")
    ap.add_argument("--out", required=True, help="Zieldatei (.png/.jpg); bei --n>1 wird _1.._n angehängt")
    group = ap.add_mutually_exclusive_group(required=True)
    group.add_argument("--prompt", help="Motivbeschreibung (ohne Stil-Präfix)")
    group.add_argument("--prompt-file", help="Datei mit der Motivbeschreibung")
    ap.add_argument("--style", help="Stil-Präfix aus tools/styles/<name>.txt")
    ap.add_argument("--ref", action="append", default=[], help="Referenzbild (mehrfach erlaubt)")
    ap.add_argument("--n", type=int, default=1, help="Varianten (max %d)" % MAX_PER_CALL)
    ap.add_argument("--aspect", default="1:1", help="Seitenverhältnis, z. B. 1:1, 16:9")
    ap.add_argument("--size", default="1K", help="512, 1K, 2K oder 4K (Lite kann nur 1K)")
    ap.add_argument("--model", default=DEFAULT_MODEL)
    ap.add_argument("--dry-run", action="store_true", help="Nur den fertigen Prompt zeigen")
    args = ap.parse_args()

    if args.n < 1 or args.n > MAX_PER_CALL:
        sys.exit("--n muss zwischen 1 und %d liegen." % MAX_PER_CALL)

    motif = Path(args.prompt_file).read_text(encoding="utf-8").strip() if args.prompt_file else args.prompt
    prompt = "%s\n\n%s" % (_style_text(args.style), motif) if args.style else motif

    if args.dry_run:
        print(prompt)
        return

    state = _load_state()
    spent = _spent_today(state)
    if spent + args.n > MAX_PER_DAY:
        sys.exit("Tagesbudget erschöpft (%d/%d Bilder). Grenze steht in imagegen.py."
                 % (spent, MAX_PER_DAY))

    if not os.environ.get("GEMINI_API_KEY"):
        sys.exit("GEMINI_API_KEY ist nicht gesetzt.")
    try:
        from google import genai
    except ImportError:
        sys.exit("google-genai fehlt:  pip install google-genai")

    parts = [{"type": "text", "text": prompt}]
    for ref in args.ref:
        path = Path(ref)
        if not path.exists():
            sys.exit("Referenzbild nicht gefunden: %s" % path)
        parts.append(_ref_part(path))

    out = Path(args.out)
    if not out.is_absolute():
        out = ROOT / out
    out.parent.mkdir(parents=True, exist_ok=True)
    # Die API liefert nur JPEG; ein PNG-Ziel wird nach dem Abruf konvertiert.

    client = genai.Client()
    written = []
    for index in range(args.n):
        target = out if args.n == 1 else out.with_name("%s_%d%s" % (out.stem, index + 1, out.suffix))
        interaction = client.interactions.create(
            model=args.model,
            input=parts,
            response_format={
                "type": "image",
                "mime_type": "image/jpeg",
                "aspect_ratio": args.aspect,
                "image_size": args.size,
            },
        )
        blob = _extract_image(interaction)
        if target.suffix.lower() == ".png":
            import io
            from PIL import Image
            Image.open(io.BytesIO(blob)).save(target)
        else:
            target.write_bytes(blob)
        written.append(target)
        _book(state, 1)
        print(target)

    print("# %d Bild(er), heute %d/%d" % (len(written), _spent_today(state), MAX_PER_DAY),
          file=sys.stderr)


if __name__ == "__main__":
    main()
