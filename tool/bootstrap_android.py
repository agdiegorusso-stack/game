from pathlib import Path
import re, shutil, subprocess, tempfile
ROOT = Path(__file__).resolve().parents[1]
android = ROOT / 'android'
if not android.exists():
    with tempfile.TemporaryDirectory(prefix='zoro-flutter-') as temp:
        scaffold = Path(temp) / 'zoro_forge'
        subprocess.run(['flutter', 'create', '--platforms=android', '--org=it.zoroforge', '--project-name=zoro_forge', '--android-language=kotlin', '--no-pub', str(scaffold)], check=True)
        shutil.copytree(scaffold / 'android', android)
shutil.copytree(ROOT / 'android_overlay', android, dirs_exist_ok=True)
gradle = android / 'app' / 'build.gradle.kts'
text = gradle.read_text()
text = re.sub(r'minSdk\s*=\s*[^\n]+', 'minSdk = 24', text)
text = re.sub(r'compileSdk\s*=\s*[^\n]+', 'compileSdk = 36', text)
text = re.sub(r'targetSdk\s*=\s*[^\n]+', 'targetSdk = 36', text)
gradle.write_text(text)
settings = android / 'settings.gradle.kts'
text = settings.read_text()
def minimum(match):
    current = tuple(int(n) for n in match.group(2).split('.'))
    floor = (8, 12, 1) if match.group(1) == 'com.android.application' else (2, 2, 0)
    chosen = match.group(2) if current >= floor else '.'.join(map(str, floor))
    return f'id("{match.group(1)}") version "{chosen}"'
text = re.sub(r'id\("(com.android.application|org.jetbrains.kotlin.android)"\) version "([0-9.]+)"', minimum, text)
settings.write_text(text)
wrapper = android / 'gradle/wrapper/gradle-wrapper.properties'
text = wrapper.read_text()
found = re.search(r'gradle-(\d+(?:\.\d+)+)-(?:all|bin)\.zip', text)
if found and tuple(map(int, found.group(1).split('.'))) < (8, 13):
    text = text.replace(found.group(0), 'gradle-8.13-bin.zip')
wrapper.write_text(text)
(android / 'gradlew').chmod(0o755)
print('Flutter Android scaffold prepared.')
