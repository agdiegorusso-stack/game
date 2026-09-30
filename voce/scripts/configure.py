"""Create a private configuration once, without printing credentials."""
import os
from pathlib import Path
import secrets
root = Path(__file__).resolve().parents[1]
target = root / '.env'
content = (root / 'backend/.env.example').read_text().replace('VOCE_APP_TOKEN=\n', 'VOCE_APP_TOKEN=' + secrets.token_urlsafe(40) + '\n')
try:
    fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
except FileExistsError:
    raise SystemExit('Configurazione già presente: non è stata modificata.')
with os.fdopen(fd, 'w') as stream:
    stream.write(content)
print('Configurazione creata. Apri .env privatamente per impostare il servizio AI e, se disponibile, LinkedIn.')
