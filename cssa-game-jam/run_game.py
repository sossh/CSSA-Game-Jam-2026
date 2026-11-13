"""Import Godot assets and launch Cosmic Detention from a source checkout."""

import os
from pathlib import Path
import subprocess
import sys


def main() -> int:
    project = Path(__file__).resolve().parent
    godot = os.environ.get("GODOT_BIN", "godot")
    command = [godot, "--path", str(project)]
    try:
        imported = subprocess.run(
            [*command, "--headless", "--editor", "--import", "--quit"]
        )
        if imported.returncode:
            return imported.returncode
        return subprocess.call([*command, *sys.argv[1:]])
    except FileNotFoundError:
        print(
            "Godot was not found. Add Godot 4.7.x to PATH or set GODOT_BIN "
            "to the Godot executable.",
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
