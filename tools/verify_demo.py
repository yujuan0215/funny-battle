#!/usr/bin/env python3
"""Runs the complete project checks; preserves each process exit status."""
import argparse, pathlib, subprocess, sys, json, re
parser = argparse.ArgumentParser()
parser.add_argument('godot', help='Godot executable path')
args = parser.parse_args()
root = pathlib.Path(__file__).resolve().parents[1]
logs = root / 'qa' / 'test-logs'
logs.mkdir(parents=True, exist_ok=True)
(root / '.test-data').mkdir(exist_ok=True)
results = []
for name in ['fork_test', 'test_spring_counter', 'test_player_feedback', 'test_intro_campaign', 'test_pixel_ui', 'test_vertical_slice']:
    cmd = [args.godot, '--headless', '--log-file', str(logs / (name + '.log')), '--script', 'res://tests/' + name + '.gd']
    run = subprocess.run(cmd, cwd=root, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
    (logs / (name + '-output.log')).write_text(run.stdout)
    # macOS system CA lookup is unrelated to this fully offline game.
    errors = [line for line in run.stdout.splitlines() if ('ERROR:' in line and 'ret != noErr' not in line) or 'SCRIPT ERROR' in line]
    result = {'suite': name, 'exit_code': run.returncode, 'passed': run.returncode == 0 and not errors, 'errors': errors}
    results.append(result)
    summary = [line for line in run.stdout.splitlines() if re.search(r'(RESULT:|checks,|tests:)', line)]
    print(('PASS' if result['passed'] else 'FAIL'), name, ' | '.join(summary), flush=True)
(logs / 'results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2))
sys.exit(0 if all(item['passed'] for item in results) else 1)
