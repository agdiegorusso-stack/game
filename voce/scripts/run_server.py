"""Loads simple KEY=value configuration; never evaluates shell code."""
import os
import sys
from pathlib import Path
root = Path(__file__).resolve().parents[1]
config = root / '.env'
if not config.exists():
    raise SystemExit('Esegui prima python3 scripts/configure.py')
for line in config.read_text().splitlines():
    line = line.strip()
    if not line or line.startswith('#'):
        continue
    key, separator, value = line.partition('=')
    if separator and key.replace('_', '').isalnum():
        os.environ.setdefault(key, value)
sys.path.insert(0, str(root / 'backend'))
from server import main
main()
