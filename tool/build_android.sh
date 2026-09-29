#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p dist build-report
flutter --version > build-report/flutter-version.txt
python3 tool/bootstrap_android.py 2>&1 | tee build-report/bootstrap.log
flutter pub get 2>&1 | tee build-report/pub-get.log
dart format lib test > build-report/format.log
flutter analyze --no-fatal-infos 2>&1 | tee build-report/analyze.log
flutter test --reporter expanded 2>&1 | tee build-report/tests.log
flutter build apk --release --target-platform android-arm64 --no-pub 2>&1 | tee build-report/build.log
cp build/app/outputs/flutter-apk/app-release.apk dist/Zoro-Forge-Flutter-2.0.0-arm64.apk
unzip -l dist/*.apk | grep -E 'lib/arm64-v8a/(libflutter|libapp).so|flutter_assets/' > build-report/flutter-native-libraries.txt
sha256sum dist/*.apk > dist/SHA256SUMS.txt
cp pubspec.lock dist/pubspec.lock
python3 - <<'VERIFY'
import zipfile
from pathlib import Path
p=next(Path('dist').glob('*.apk'))
with zipfile.ZipFile(p) as z:
    names=z.namelist()
    assert 'lib/arm64-v8a/libflutter.so' in names
    assert 'lib/arm64-v8a/libapp.so' in names
    assert 'assets/flutter_assets/assets/catalog.json' in names
    print('Verified real Flutter release APK:',p,p.stat().st_size)
VERIFY
