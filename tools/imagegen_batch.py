# -*- coding: utf-8 -*-
"""Batch-Bildgenerator: viele Motive in EINEM Gemini-Batch-Job (50 % Rabatt, bis 24 h).

    python tools/imagegen_batch.py submit --run <ordner> --manifest <json> --style charm --n 3
    python tools/imagegen_batch.py poll   --run <ordner>      # wartet; Exit 0 = fertig, 1 = Fehler, 2 = Zeit
    python tools/imagegen_batch.py fetch  --run <ordner>      # schreibt <id>_<k>.png in den Ordner
    python tools/imagegen_batch.py sheets --run <ordner>      # ein Kontaktbogen je Motiv (sheets/<id>.png)

Manifest: Liste von {"id": ..., "prompt": ...} - der Stil kommt wie bei imagegen.py aus
tools/styles/<name>.txt. Der Job-Name steht danach in <run>/batch.json; Anfragen und
Antworten liegen als JSONL daneben, damit ein Abbruch nichts verliert.
"""
import argparse
import base64
import io
import json
import os
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import imagegen  # noqa: E402  (Stil-Präfix, Zähler-Datei, Standardmodell)

# Obergrenze je Job als Tippfehler-Bremse; die Kosten stehen vor dem Absenden auf stderr.
MAX_PER_BATCH = 400
PRICE_PER_IMAGE = {"gemini-3.1-flash-lite-image": 0.034}
BATCH_DISCOUNT = 0.5
DONE_STATES = ("SUCCEEDED", "PARTIALLY_SUCCEEDED")
DEAD_STATES = ("FAILED", "CANCELLED", "EXPIRED")


def _client():
    if not os.environ.get("GEMINI_API_KEY"):
        sys.exit("GEMINI_API_KEY ist nicht gesetzt.")
    from google import genai
    return genai.Client()


def _run_dir(args) -> Path:
    run = Path(args.run)
    run.mkdir(parents=True, exist_ok=True)
    return run


def _batch_info(run: Path) -> dict:
    path = run / "batch.json"
    if not path.exists():
        sys.exit("Kein Job in %s (erst submit)." % run)
    return json.loads(path.read_text(encoding="utf-8"))


def _cost(model: str, images: int) -> str:
    price = PRICE_PER_IMAGE.get(model)
    if price is None:
        return "Preis fuer %s unbekannt" % model
    return "~$%.2f (%d x $%.3f x %.0f %%)" % (images * price * BATCH_DISCOUNT, images, price,
                                             BATCH_DISCOUNT * 100)


def cmd_submit(args) -> None:
    run = _run_dir(args)
    if (run / "batch.json").exists() and not args.force:
        sys.exit("In %s liegt schon ein Job; --force ueberschreibt batch.json." % run)
    manifest = json.loads(Path(args.manifest).read_text(encoding="utf-8"))
    style = imagegen._style_text(args.style) if args.style else ""
    lines, keys = [], []
    for entry in manifest:
        prompt = "%s\n\n%s" % (style, entry["prompt"]) if style else entry["prompt"]
        for k in range(1, args.n + 1):
            key = "%s_%d" % (entry["id"], k)
            keys.append(key)
            lines.append(json.dumps({
                "key": key,
                "request": {
                    "contents": [{"role": "user", "parts": [{"text": prompt}]}],
                    "generation_config": {
                        "response_modalities": ["IMAGE"],
                        "image_config": {"aspect_ratio": args.aspect, "image_size": args.size},
                    },
                },
            }, ensure_ascii=False))
    if len(lines) > MAX_PER_BATCH:
        sys.exit("%d Anfragen > MAX_PER_BATCH %d." % (len(lines), MAX_PER_BATCH))
    print("# %d Motive x %d = %d Bilder, %s, Modell %s"
          % (len(manifest), args.n, len(lines), _cost(args.model, len(lines)), args.model),
          file=sys.stderr)
    requests_path = run / "requests.jsonl"
    requests_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    if args.dry_run:
        print(lines[0])
        return
    client = _client()
    uploaded = client.files.upload(
        file=str(requests_path),
        config={"display_name": run.name + "-requests", "mime_type": "jsonl"})
    job = client.batches.create(model=args.model, src=uploaded.name,
                                config={"display_name": run.name})
    info = {"job": job.name, "model": args.model, "n_requests": len(lines), "keys": keys,
            "src_file": uploaded.name, "submitted": time.strftime("%Y-%m-%d %H:%M:%S"),
            "state": _state_name(job)}
    (run / "batch.json").write_text(json.dumps(info, indent=1), encoding="utf-8")
    print(job.name)
    print("# Zustand %s" % _state_name(job), file=sys.stderr)


def _state_name(job) -> str:
    return str(getattr(job.state, "name", job.state)).replace("JOB_STATE_", "")


def cmd_status(args) -> None:
    run = _run_dir(args)
    info = _batch_info(run)
    client = _client()  # als Variable: ein Temporaer-Client schliesst sich vor dem Request
    job = client.batches.get(name=info["job"])
    print(_state_name(job), job.completion_stats or "")


def cmd_poll(args) -> None:
    run = _run_dir(args)
    info = _batch_info(run)
    client = _client()
    deadline = time.time() + args.timeout
    while True:
        job = client.batches.get(name=info["job"])
        state = _state_name(job)
        print("%s %s %s" % (time.strftime("%H:%M:%S"), state, job.completion_stats or ""), flush=True)
        if state in DONE_STATES:
            return
        if state in DEAD_STATES:
            print(job.error, file=sys.stderr)
            sys.exit(1)
        if time.time() > deadline:
            sys.exit(2)
        time.sleep(args.every)


def _find_inline(node):
    """Erstes Bild in einer Antwort, egal ob camelCase oder snake_case."""
    if isinstance(node, dict):
        for key in ("inlineData", "inline_data"):
            blob = node.get(key)
            if isinstance(blob, dict) and blob.get("data"):
                return blob["data"]
        for value in node.values():
            found = _find_inline(value)
            if found:
                return found
    elif isinstance(node, list):
        for value in node:
            found = _find_inline(value)
            if found:
                return found
    return None


def _save_png(data, target: Path) -> None:
    from PIL import Image
    raw = data if isinstance(data, bytes) else base64.b64decode(data)
    Image.open(io.BytesIO(raw)).save(target)


def cmd_fetch(args) -> None:
    run = _run_dir(args)
    info = _batch_info(run)
    client = _client()
    job = client.batches.get(name=info["job"])
    state = _state_name(job)
    if state not in DONE_STATES:
        sys.exit("Job steht auf %s - noch nichts abzuholen." % state)
    results = []
    if job.dest and job.dest.file_name:
        raw = client.files.download(file=job.dest.file_name)
        (run / "responses.jsonl").write_bytes(raw)
        for line in raw.decode("utf-8").splitlines():
            if line.strip():
                results.append(json.loads(line))
    elif job.dest and job.dest.inlined_responses:
        for index, item in enumerate(job.dest.inlined_responses):
            results.append({"key": info["keys"][index],
                            "response": item.response.model_dump() if item.response else None,
                            "error": item.error.model_dump() if item.error else None})
    else:
        sys.exit("Job fertig, aber ohne Ziel-Datei und ohne Inline-Antworten.")
    written, errors = [], {}
    for item in results:
        key = item.get("key") or "unbenannt_%d" % len(written)
        if item.get("error"):
            errors[key] = item["error"]
            continue
        data = _find_inline(item.get("response"))
        if not data:
            errors[key] = "kein Bild in der Antwort (Filter?)"
            continue
        target = run / (key + ".png")
        _save_png(data, target)
        written.append(target)
    if errors:
        (run / "errors.json").write_text(json.dumps(errors, indent=1, ensure_ascii=False),
                                         encoding="utf-8")
    state_data = imagegen._load_state()
    day = time.strftime("%Y-%m-%d")
    batch = state_data.setdefault("batch", {})
    batch[day] = batch.get(day, 0) + len(written)
    imagegen.STATE_FILE.write_text(json.dumps(state_data), encoding="utf-8")
    print("# %d Bilder geschrieben, %d Fehler (%s), Job %s"
          % (len(written), len(errors), run / "errors.json" if errors else "-", state),
          file=sys.stderr)


def cmd_sheets(args) -> None:
    from PIL import Image, ImageDraw
    run = _run_dir(args)
    out = run / "sheets"
    out.mkdir(exist_ok=True)
    groups = {}
    for png in sorted(run.glob("*_[0-9].png")):
        groups.setdefault(png.stem.rsplit("_", 1)[0], []).append(png)
    for cid, files in groups.items():
        thumb = args.thumb
        sheet = Image.new("RGB", (thumb * len(files), thumb + 28), (60, 60, 60))
        draw = ImageDraw.Draw(sheet)
        for index, png in enumerate(files):
            img = Image.open(png).convert("RGB").resize((thumb, thumb))
            sheet.paste(img, (index * thumb, 28))
            draw.text((index * thumb + 6, 8), png.stem, fill=(230, 230, 230))
        sheet.save(out / (cid + ".png"))
    print("# %d Kontaktboegen in %s" % (len(groups), out), file=sys.stderr)


def cmd_winners(args) -> None:
    """picks.json ({id: {pick: k}}) -> winners/<id>.png plus Uebersichts-Raster."""
    import shutil
    from PIL import Image, ImageDraw
    run = _run_dir(args)
    picks = json.loads((run / "picks.json").read_text(encoding="utf-8"))
    out = run / "winners"
    out.mkdir(exist_ok=True)
    chosen = []
    for cid in sorted(picks):
        k = picks[cid].get("pick")
        if k is None:
            continue
        src = picks[cid].get("file") or str(run / ("%s_%s.png" % (cid, k)))
        shutil.copyfile(src, out / (cid + ".png"))
        chosen.append(cid)
    cols, thumb, label = args.cols, args.thumb, 22
    per_sheet = cols * args.rows
    for index in range(0, len(chosen), per_sheet):
        page = chosen[index:index + per_sheet]
        rows = (len(page) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * thumb, rows * (thumb + label)), (60, 60, 60))
        draw = ImageDraw.Draw(sheet)
        for pos, cid in enumerate(page):
            x, y = (pos % cols) * thumb, (pos // cols) * (thumb + label)
            sheet.paste(Image.open(out / (cid + ".png")).convert("RGB").resize((thumb, thumb)), (x, y + label))
            draw.text((x + 4, y + 5), cid, fill=(230, 230, 230))
        sheet.save(out / ("overview_%d.png" % (index // per_sheet + 1)))
    print("# %d Gewinner in %s, %d Uebersichten" % (len(chosen), out, (len(chosen) + per_sheet - 1) // per_sheet),
          file=sys.stderr)


def main() -> None:
    ap = argparse.ArgumentParser(description="Gemini-Batch-Bildgenerator fuer Fumble-Assets")
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("submit")
    s.add_argument("--run", required=True, help="Lauf-Ordner (E:/Generated Images/Fumble/<lauf>)")
    s.add_argument("--manifest", required=True, help="JSON-Liste von {id, prompt}")
    s.add_argument("--style", help="Stil-Praefix aus tools/styles/<name>.txt")
    s.add_argument("--n", type=int, default=3, help="Kandidaten je Motiv")
    s.add_argument("--aspect", default="1:1")
    s.add_argument("--size", default="1K")
    s.add_argument("--model", default=imagegen.DEFAULT_MODEL)
    s.add_argument("--dry-run", action="store_true")
    s.add_argument("--force", action="store_true")
    s.set_defaults(func=cmd_submit)
    for name, func in (("status", cmd_status), ("fetch", cmd_fetch)):
        p = sub.add_parser(name)
        p.add_argument("--run", required=True)
        p.set_defaults(func=func)
    p = sub.add_parser("poll")
    p.add_argument("--run", required=True)
    p.add_argument("--every", type=int, default=120, help="Sekunden zwischen zwei Abfragen")
    p.add_argument("--timeout", type=int, default=3 * 3600)
    p.set_defaults(func=cmd_poll)
    p = sub.add_parser("sheets")
    p.add_argument("--run", required=True)
    p.add_argument("--thumb", type=int, default=512)
    p.set_defaults(func=cmd_sheets)
    p = sub.add_parser("winners")
    p.add_argument("--run", required=True)
    p.add_argument("--cols", type=int, default=6)
    p.add_argument("--rows", type=int, default=4)
    p.add_argument("--thumb", type=int, default=256)
    p.set_defaults(func=cmd_winners)
    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
