# -*- coding: utf-8 -*-
"""Texturen eines .glb verkleinern und neu komprimieren; Geometrie bleibt byteweise gleich.

    python tools/shrink_glb.py <quelle.glb> <ziel.glb> [--max 1024] [--quality 88] [--ground]

Meshy liefert 4096er-Karten in fast unkomprimiertem JPEG (15-30 MB je Charm); für einen
Charm, der auf dem Filz ~100 px groß steht, reichen 1024er. --ground setzt das Modell mit
dem Fuß auf Y = 0 (Tripo-Konvention), indem der Wurzelknoten eine Translation bekommt.
"""
import argparse
import io
import json
import struct
import sys
from pathlib import Path

from PIL import Image

MAGIC = 0x46546C67  # 'glTF'


def _pad(data: bytes, fill: bytes) -> bytes:
    return data + fill * ((4 - len(data) % 4) % 4)


def read_glb(path: Path):
    blob = path.read_bytes()
    magic, _version, _length = struct.unpack_from("<III", blob, 0)
    if magic != MAGIC:
        sys.exit("%s ist kein GLB." % path)
    json_len, _ = struct.unpack_from("<II", blob, 12)
    gltf = json.loads(blob[20:20 + json_len])
    bin_offset = 20 + json_len
    bin_len, _ = struct.unpack_from("<II", blob, bin_offset)
    return gltf, blob[bin_offset + 8:bin_offset + 8 + bin_len]


def write_glb(path: Path, gltf: dict, binary: bytes) -> None:
    json_chunk = _pad(json.dumps(gltf, separators=(",", ":")).encode("utf-8"), b" ")
    bin_chunk = _pad(binary, b"\0")
    total = 12 + 8 + len(json_chunk) + 8 + len(bin_chunk)
    out = bytearray(struct.pack("<III", MAGIC, 2, total))
    out += struct.pack("<II", len(json_chunk), 0x4E4F534A) + json_chunk
    out += struct.pack("<II", len(bin_chunk), 0x004E4942) + bin_chunk
    path.write_bytes(out)


def shrink_image(data: bytes, max_size: int, quality: int) -> bytes:
    img = Image.open(io.BytesIO(data))
    if max(img.size) > max_size:
        target = (max_size, max_size) if img.size[0] == img.size[1] \
            else tuple(max(1, d * max_size // max(img.size)) for d in img.size)
        img = img.resize(target, getattr(getattr(Image, "Resampling", Image), "LANCZOS"))
    buf = io.BytesIO()
    img.convert("RGB").save(buf, "JPEG", quality=quality, optimize=True)
    return buf.getvalue()


def ground(gltf: dict, binary: bytes) -> None:
    """Fuß auf Y = 0: kleinstes Y aller Positions-Accessoren, als Translation der Wurzeln."""
    ys = []
    for mesh in gltf.get("meshes", []):
        for prim in mesh["primitives"]:
            acc = gltf["accessors"][prim["attributes"]["POSITION"]]
            if "min" in acc:
                ys.append(acc["min"][1])
    if not ys:
        return
    scene = gltf["scenes"][gltf.get("scene", 0)]
    for index in scene["nodes"]:
        node = gltf["nodes"][index]
        if "matrix" in node:
            node["matrix"][13] -= min(ys)  # spaltenweise Matrix: Translation Y
        else:
            t = node.get("translation", [0.0, 0.0, 0.0])
            node["translation"] = [t[0], t[1] - min(ys), t[2]]


def shrink(src: Path, dst: Path, max_size: int, quality: int, do_ground: bool) -> tuple:
    gltf, binary = read_glb(src)
    image_views = {img["bufferView"]: i for i, img in enumerate(gltf.get("images", [])) if "bufferView" in img}
    new_bin = bytearray()
    for index, view in enumerate(gltf["bufferViews"]):
        start = view.get("byteOffset", 0)
        data = binary[start:start + view["byteLength"]]
        if index in image_views:
            data = shrink_image(data, max_size, quality)
            gltf["images"][image_views[index]]["mimeType"] = "image/jpeg"
        view["byteOffset"] = len(new_bin)
        view["byteLength"] = len(data)
        new_bin += _pad(data, b"\0")
    gltf["buffers"][0]["byteLength"] = len(new_bin)
    if do_ground:
        ground(gltf, bytes(new_bin))
    write_glb(dst, gltf, bytes(new_bin))
    return src.stat().st_size, dst.stat().st_size


def main() -> None:
    ap = argparse.ArgumentParser(description="GLB-Texturen verkleinern")
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--max", type=int, default=1024, help="längste Texturkante")
    ap.add_argument("--quality", type=int, default=88, help="JPEG-Qualität")
    ap.add_argument("--ground", action="store_true", help="Fuß auf Y = 0 setzen")
    args = ap.parse_args()
    before, after = shrink(Path(args.src), Path(args.dst), args.max, args.quality, args.ground)
    print("%s: %d KB -> %d KB" % (Path(args.dst).name, before // 1024, after // 1024))


if __name__ == "__main__":
    main()
