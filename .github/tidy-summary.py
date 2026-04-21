#  AUI Framework - Declarative UI toolkit for modern C++20
#  Copyright (C) 2020-2024 Alex2772 and Contributors
#
#  SPDX-License-Identifier: MPL-2.0
#
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at http://mozilla.org/MPL/2.0/.

"""

Runs clang-tidy on all src/ source files using the compile_commands.json
produced by xmake's plugin.compile_commands.autoupdate rule (.vscode/).

Expected usage (from project root, after xmake -b example_app):
    python3 .github/tidy-summary.py

Counts occurrences of each diagnostic and prints them sorted. Exits non-zero
if any diagnostics are found, so CI fails on new clang-tidy warnings.

"""

import re
import shutil
import subprocess
import sys
from pathlib import Path

REGEX_DIAGNOSTIC = re.compile(r'.+ \[([a-zA-Z0-9-]+)(,.+)?\]$')
assert REGEX_DIAGNOSTIC.match("/home/AUI/Common/ASmallVector.h:326:5: warning: function 'contains' should be marked [[nodiscard]] [modernize-use-nodiscard,-warnings-as-errors]").group(1) == 'modernize-use-nodiscard'


if __name__ == '__main__':
    project_root = Path(__file__).resolve().parent.parent
    compile_commands = project_root / '.vscode' / 'compile_commands.json'

    if not compile_commands.is_file():
        raise RuntimeError(
            f'compile_commands.json not found at {compile_commands}. '
            'Run: xmake f -m debug --toolchain=clang -y && xmake -b example_app'
        )

    # Prefer the unversioned binary; fall back to versioned ones (Ubuntu ships
    # clang-tidy as run-clang-tidy-18 etc. depending on the default version).
    run_tidy = (
        shutil.which('run-clang-tidy') or
        shutil.which('run-clang-tidy-18') or
        shutil.which('run-clang-tidy-17') or
        shutil.which('run-clang-tidy-16')
    )
    if run_tidy is None:
        raise RuntimeError('run-clang-tidy not found. Install the clang-tidy package.')

    sources = sorted((project_root / 'src').glob('*.cpp'))

    # run-clang-tidy runs checks in parallel across all translation units.
    tidy_process = subprocess.Popen(
        [run_tidy, '-p', str(compile_commands.parent)] + [str(s) for s in sources],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        cwd=project_root,
    )

    def lines(pipe):
        while True:
            l = pipe.readline()
            if not l:
                return
            l = l.decode('utf-8').rstrip('\n')
            print(l)
            yield l

    count = {}
    for line in lines(tidy_process.stdout):
        line = line.strip()
        if m := REGEX_DIAGNOSTIC.match(line):
            diagnostic_name = m.group(1)
            if diagnostic_name.startswith("-W"):
                # TODO unskip warnings
                continue

            count[diagnostic_name] = count.get(diagnostic_name, 0) + 1

    count_as_list = count.items()
    print('Sorted by count:')
    for i in sorted(count_as_list, key=lambda x: x[1], reverse=True):
        print(f"{i[0]}: {i[1]}")

    print('')
    print('Sorted by name:')
    for i in sorted(count_as_list, key=lambda x: x[0]):
        print(f"{i[0]}: {i[1]}")

    print('')
    total = sum(count.values())
    print(f'Total: {total}')
    if total > 0:
        exit(-1)
