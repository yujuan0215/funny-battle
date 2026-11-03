#!/usr/bin/env python3
"""Export the Web preset, test the exact PCK, then create an itch.io ZIP."""
import argparse
import pathlib
import subprocess
import zipfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('godot', help='Godot executable, with matching Web export templates installed')
args = parser.parse_args()
root = pathlib.Path(__file__).resolve().parents[1]
godot = str(pathlib.Path(args.godot).expanduser().resolve())
build = root / 'build'
web = build / 'web'
web.mkdir(parents=True, exist_ok=True)


def run(arguments, logfile):
    command = [godot, '--headless', '--path', str(root), '--log-file', str(build / logfile), *arguments]
    result = subprocess.run(command, cwd=root, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (build / (logfile + '.output.txt')).write_text(result.stdout)
    errors = [line for line in result.stdout.splitlines()
              if 'SCRIPT ERROR' in line or ('ERROR:' in line and 'ret != noErr' not in line)]
    if result.returncode or errors:
        raise SystemExit(result.stdout or 'Godot export verification failed')
    print(result.stdout.splitlines()[-1] if result.stdout.splitlines() else 'Done', flush=True)


run(['--editor', '--import'], 'web-import.log')
run(['--export-release', 'Web', str(web / 'index.html')], 'web-export.log')
# Source-editor tests alone would miss a CSV dropped by the export importer.
run(['--main-pack', str(web / 'index.pck'), '--script', str(root / 'tests/test_export_props.gd')], 'web-pack-test.log')
archive = build / 'funny-battle-web.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as package:
    # Include only files generated for this Web preset's index entry point.
    for item in sorted(web.glob('index.*')):
        if item.is_file():
            package.write(item, item.name)
with zipfile.ZipFile(archive) as package:
    if package.testzip() is not None or not {'index.html', 'index.js', 'index.wasm', 'index.pck'} <= set(package.namelist()):
        raise SystemExit('The ZIP is incomplete or corrupt')
print(f'Ready to upload: {archive}')
