from __future__ import annotations

import argparse
import hashlib
import urllib.request
from pathlib import Path

OPENSLR_FILES = {
    "voxceleb1_test.txt": "https://openslr.trmal.net/resources/49/voxceleb1_test.txt",
    "voxceleb1_test_v2.txt": "https://openslr.trmal.net/resources/49/voxceleb1_test_v2.txt",
    "vox1_meta.csv": "https://openslr.trmal.net/resources/49/vox1_meta.csv",
    "voxceleb1_sitw_overlap.txt": "https://openslr.trmal.net/resources/49/voxceleb1_sitw_overlap.txt",
}

VGG_META_FILES = {
    "veri_test.txt": "https://www.robots.ox.ac.uk/~vgg/data/voxceleb/meta/veri_test.txt",
    "veri_test2.txt": "https://www.robots.ox.ac.uk/~vgg/data/voxceleb/meta/veri_test2.txt",
    "iden_split.txt": "https://www.robots.ox.ac.uk/~vgg/data/voxceleb/meta/iden_split.txt",
}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        while True:
            chunk = fh.read(8192)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def download(url: str, path: Path) -> None:
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = resp.read()
    path.write_bytes(data)


def main() -> None:
    parser = argparse.ArgumentParser(description="Download VoxCeleb1 trial/meta files for local evaluation")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("tools/voxceleb_eval/data"),
        help="Destination for metadata and trial files",
    )
    args = parser.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)

    files = {**OPENSLR_FILES, **VGG_META_FILES}
    for name, url in files.items():
        path = args.output_dir / name
        try:
            download(url, path)
            print(f"Downloaded {name}: {url}")
            print(f"  sha256={sha256(path)}")
        except Exception as exc:
            print(f"Failed {name}: {url} -> {exc}")

    print("Metadata preparation done.")
    print("Note: VoxCeleb1 audio archives are no longer hosted on the official VGG page.")
    print("      Place extracted wav files under your local dataset root before running evaluation.")


if __name__ == "__main__":
    main()
