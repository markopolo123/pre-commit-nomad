#! /usr/bin/env python
from typing import Sequence

import argparse
import os
import subprocess

def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('filenames', nargs='*', help='Filenames to check.')
    args = parser.parse_args(argv)

    retval = 0
    for filename in args.filenames:
        try:
            base = os.path.abspath(filename)
            dir_path = os.path.dirname(base)
            print(base)
            subprocess.check_output(["nomad", "validate", f"{filename}"], cwd=dir_path)
        except subprocess.CalledProcessError as e:
            print(f'{filename}: {e.output}')
            retval = 1
    return retval


if __name__ == '__main__':
    raise SystemExit(main())
