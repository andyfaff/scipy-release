#!/usr/bin/env python
"""
check_license.py [MODULE]

Check the presence of a LICENSE.txt in the installed module directory,
and that it appears to contain text prevalent for a SciPy binary
distribution.

"""
import pathlib
import sys
import re
import argparse


def check_text(text):
    ok = "Copyright (c)" in text and re.search(
        r"This binary distribution of \w+ can also bundle the following software",
        text,
        re.IGNORECASE
    )
    return ok


def main():
    p = argparse.ArgumentParser(usage=__doc__.rstrip())
    p.add_argument("module", nargs="?", default="scipy")
    args = p.parse_args()

    # Drop '' from sys.path
    sys.path.pop(0)

    # Find module path
    __import__(args.module)
    mod = sys.modules[args.module]

    # LICENSE.txt is installed in the .dist-info directory, so find it there
    sitepkgs = pathlib.Path(mod.__file__).parent.parent
    distinfo_path = next(iter(sitepkgs.glob("scipy-*.dist-info")))

    # Check license text
    license_txt = distinfo_path / "LICENSE.txt"
    with open(license_txt, encoding="utf-8") as f:
        text = f.read()

    ok = check_text(text)
    if not ok:
        print(
            f"ERROR: License text {license_txt} does not contain expected "
            "text fragments\n"
        )
        print(text)
        sys.exit(1)

    sys.exit(0)


if __name__ == "__main__":
    main()
