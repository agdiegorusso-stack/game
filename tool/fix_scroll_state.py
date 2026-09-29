"""Keep disclosure booleans separate from each page's saved scroll offset."""
from pathlib import Path
import re
ROOT = Path(__file__).resolve().parents[1]
keys = {
    'dojo_screen.dart': ["const PageStorageKey<String>('dojo-three-swords-disclosure')"],
    'progress_screen.dart': ["const PageStorageKey<String>('progress-measurements-disclosure')"],
    'settings_screen.dart': ["const PageStorageKey<String>('settings-privacy-disclosure')", "const PageStorageKey<String>('settings-sources-disclosure')"],
    'video_screen.dart': ["PageStorageKey<String>('exercise-${ex.id}-errors-disclosure')", "PageStorageKey<String>('exercise-${ex.id}-alternatives-disclosure')"],
}
for name, expected in keys.items():
    p = ROOT / 'lib/src' / name
    text = p.read_text()
    matches = list(re.finditer(r'\bExpansionTile\(', text))
    if len(matches) != len(expected):
        raise RuntimeError(f'{name}: expected {len(expected)} disclosures, found {len(matches)}')
    for match, key in reversed(list(zip(matches, expected))):
        if re.match(r'\s*key\s*:', text[match.end():]):
            if key not in text[match.end():match.end()+160]:
                raise RuntimeError(f'{name}: unexpected pre-existing key')
            continue
        text = text[:match.end()] + '\nkey: ' + key + ',' + text[match.end():]
    p.write_text(text)
p = ROOT / 'pubspec.yaml'
p.write_text(re.sub(r'version: .*', 'version: 2.0.2+20004', p.read_text()))
p = ROOT / 'lib/src/settings_screen.dart'
p.write_text(p.read_text().replace('2.0.1', '2.0.2'))
print('All six expansion tiles now use distinct PageStorageKeys. App ID and database are unchanged.')
