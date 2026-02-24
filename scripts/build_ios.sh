#!/bin/bash
set -euo pipefail

# iOS 릴리스 빌드 스크립트
# Kakao 키를 dart-define으로 포함하여 빌드합니다.
# 빌드 후 Xcode에서 Archive를 실행하세요.

cd "$(dirname "$0")/.."

echo "==> flutter build ios (release, no-codesign)"
flutter build ios --release --no-codesign \
  --dart-define-from-file=dart_defines.env

echo ""
echo "==> Done. Now open Xcode and Archive:"
echo "   open ios/Runner.xcworkspace"
