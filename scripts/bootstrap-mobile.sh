#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOBILE="$ROOT/mobile"
command -v flutter >/dev/null 2>&1 || { echo "Flutter 3.44+ is required." >&2; exit 1; }
cd "$MOBILE"
if [[ ! -d android ]]; then
  flutter create --platforms=android,ios,web --project-name anatomy_atlas --org com.anatomyatlas .
fi
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
printf '\nMobile workspace is ready. Run: cd mobile && flutter run\n'
