#!/usr/bin/env python3
"""Exercise pre-build failures without launching apps or enumerating real processes."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class RunAppTests(unittest.TestCase):
    def test_inventory_failures_never_reach_build(self):
        source = Path(__file__).resolve().parent.parent
        # Fail the initial inventory, the pre-stop inventory, and both stop checks.
        for fail_at in (1, 2, 3, 4):
            with self.subTest(fail_at=fail_at), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / "tools").mkdir()
                (root / "app/Resources").mkdir(parents=True)
                (root / "bin").mkdir()
                shutil.copy(source / "tools/run-app.sh", root / "tools/run-app.sh")
                shutil.copy(source / "app/Resources/Info.plist", root / "app/Resources/Info.plist")
                ps = root / "bin/ps"
                ps.write_text('''#!/bin/bash
n=0
[[ ! -f "$TEST_COUNTER" ]] || n=$(cat "$TEST_COUNTER")
n=$((n + 1))
echo "$n" > "$TEST_COUNTER"
if [[ "$n" == "$TEST_FAIL_AT" ]]; then
    echo 'Process inventory unavailable' >&2
    exit 73
fi
''')
                make = root / "bin/make"
                make.write_text('#!/bin/bash\ntouch "$TEST_BUILD_MARKER"\nexit 99\n')
                ps.chmod(0o755)
                make.chmod(0o755)
                marker = root / "built"
                environment = dict(os.environ, PATH=f"{root / 'bin'}:/usr/bin:/bin",
                                   TEST_COUNTER=str(root / "counter"), TEST_FAIL_AT=str(fail_at),
                                   TEST_BUILD_MARKER=str(marker))
                result = subprocess.run(["bash", str(root / "tools/run-app.sh")],
                                        env=environment, capture_output=True, text=True)
                self.assertEqual(result.returncode, 73, result.stderr)
                self.assertFalse(marker.exists(), "Inventory failure reached app replacement")


if __name__ == "__main__":
    unittest.main()
