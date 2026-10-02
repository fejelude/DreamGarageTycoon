"""Compile every tracked game script and execute tests against the actual source.

No Roblox services are contacted. Luau service tests use deterministic mocks;
Studio integration and failure injection are documented in RELEASE_SAFETY.md.
"""
import argparse
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument("--compiler", required=True)
parser.add_argument("--runtime", required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
tracked = subprocess.check_output(["git", "ls-files", "-z"], cwd=root).decode().split("\0")
scripts = [root / name for name in tracked if name and (
    ("/" not in name and not Path(name).suffix) or name.endswith(".luau")
)]
if len([path for path in scripts if path.parent == root]) < 163:
    raise SystemExit("Game source discovery is incomplete")
failed = []
for path in scripts:
    result = subprocess.run([args.compiler, str(path)], stdout=subprocess.DEVNULL,
                            stderr=subprocess.PIPE, text=True)
    if result.returncode:
        failed.append(str(path.relative_to(root)))
        print(result.stderr)
if failed:
    raise SystemExit("Compilation failed: " + ", ".join(failed))
print(f"Compiled {len(scripts)} Luau files", flush=True)
for test in sorted((root / "tests").glob("*.luau")):
    # Insert repository sources into lexical wrappers rather than duplicating
    # the implementation in the test. Luau CLI does not supply Roblox globals.
    bundle = test.read_text()
    for name in ("InboxService",):
        marker = "-- SOURCE:" + name
        if marker in bundle:
            bundle = bundle.replace(marker, (root / name).read_text())
    with tempfile.TemporaryDirectory() as temporary:
        script = Path(temporary) / test.name
        script.write_text(bundle)
        subprocess.run([args.runtime, str(script)], check=True)
