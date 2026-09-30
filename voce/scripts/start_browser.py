"""Run the single-user API and browser collector on the same computer."""
import subprocess
import sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
api=subprocess.Popen([sys.executable,str(root/'scripts/run_server.py')],cwd=root)
try:
    browser=subprocess.Popen([sys.executable,'-m','browser.collector','run'],cwd=root)
    code=browser.wait()
    print('Il raccoglitore si è fermato. Lo stato resta consultabile; premi Ctrl+C per chiudere il server.')
    api.wait()
except KeyboardInterrupt:
    pass
finally:
    if 'browser' in locals() and browser.poll() is None: browser.terminate()
    api.terminate()
