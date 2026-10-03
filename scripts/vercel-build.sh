#!/usr/bin/env bash
# Builds the Flutter Web app on Vercel (which has no Flutter SDK by default).
# Required environment variables: SUPABASE_URL, SUPABASE_ANON_KEY, DARI_PUBLIC_BASE_URL.
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.6}"

for name in SUPABASE_URL SUPABASE_ANON_KEY DARI_PUBLIC_BASE_URL; do
  if [ -z "${!name:-}" ]; then
    echo "Missing required environment variable: $name" >&2
    exit 1
  fi
done

FLUTTER_DIR="${HOME}/flutter-sdk"
if [ ! -x "${FLUTTER_DIR}/bin/flutter" ]; then
  git clone --depth 1 --branch "${FLUTTER_VERSION}" \
    https://github.com/flutter/flutter.git "${FLUTTER_DIR}"
fi
export PATH="${FLUTTER_DIR}/bin:${PATH}"
export FLUTTER_SUPPRESS_ANALYTICS=true CI=true

flutter --version
flutter config --disable-analytics >/dev/null 2>&1 || true
flutter pub get
flutter build web --release \
  --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}" \
  --dart-define=DARI_PUBLIC_BASE_URL="${DARI_PUBLIC_BASE_URL}"
