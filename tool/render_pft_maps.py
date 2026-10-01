"""Reproduce the floor-plan crops from LSU's published building guide.

Requires Python 3 and Poppler's pdftoppm. No Python packages are needed.
"""

import hashlib
from pathlib import Path
import shutil
import subprocess
import tempfile
import urllib.request

SOURCE = "https://www.lsu.edu/eng/images/pft_floorplan_guide2_webupdated2021.pdf"
SHA256 = "677cee7068baeb6bb019a2f14705069f072aeb3b82d34d5fdb28d56de956f8a8"


def main():
    renderer = shutil.which("pdftoppm")
    if renderer is None:
        raise SystemExit("Install Poppler so pdftoppm is available on PATH.")
    destination = Path(__file__).resolve().parent.parent / "assets" / "maps"
    with tempfile.TemporaryDirectory(prefix="pft-floor-plans-") as scratch:
        scratch = Path(scratch)
        pdf = scratch / "lsu-pft-guide.pdf"
        with urllib.request.urlopen(SOURCE, timeout=60) as response:
            data = response.read()
        if hashlib.sha256(data).hexdigest() != SHA256:
            raise SystemExit("LSU's PDF has changed. Inspect it before changing assets or coordinates.")
        pdf.write_bytes(data)
        subprocess.run(
            [renderer, "-f", "2", "-l", "4", "-scale-to", "4000",
             "-x", "1380", "-y", "80", "-W", "2520", "-H", "2300",
             "-png", str(pdf), str(scratch / "floor")],
            check=True,
        )
        destination.mkdir(parents=True, exist_ok=True)
        for floor in range(1, 4):
            target = destination / f"pft-floor-{floor}.png"
            shutil.copyfile(scratch / f"floor-{floor + 1}.png", target)
            print(f"Rendered {target.name}")


if __name__ == "__main__":
    main()
