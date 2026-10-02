#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$ROOT_DIR/test-fixtures/android14"
WORK_DIR="$ROOT_DIR/build/android14-integration"
TOOLS_DIR="$ROOT_DIR/dist/lib"

ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
if [[ -z "$ANDROID_SDK_ROOT" ]]; then
  echo "ANDROID_SDK_ROOT or ANDROID_HOME must be set." >&2
  exit 1
fi

BUILD_TOOLS_VERSION="34.0.0"
BUILD_TOOLS_DIR="$ANDROID_SDK_ROOT/build-tools/$BUILD_TOOLS_VERSION"
ANDROID_JAR="$ANDROID_SDK_ROOT/platforms/android-34/android.jar"
AAPT2="$BUILD_TOOLS_DIR/aapt2"
D8="$BUILD_TOOLS_DIR/d8"

APKTOOL_JAR="$TOOLS_DIR/apktool.jar"
SIGNER_JAR="$TOOLS_DIR/uber-apk-signer.jar"

for required in "$AAPT2" "$D8" "$ANDROID_JAR" "$APKTOOL_JAR" "$SIGNER_JAR"; do
  if [[ ! -e "$required" ]]; then
    echo "Missing required file: $required" >&2
    exit 1
  fi
done

rm -rf "$WORK_DIR"
mkdir -p   "$WORK_DIR/gen"   "$WORK_DIR/classes"   "$WORK_DIR/dex"   "$WORK_DIR/signed-original"   "$WORK_DIR/signed-rebuilt"

echo "==> Compiling Android 14 resources"
"$AAPT2" compile   --dir "$FIXTURE_DIR/res"   -o "$WORK_DIR/compiled-res.zip"

echo "==> Linking Android 14 resources"
"$AAPT2" link   -I "$ANDROID_JAR"   --manifest "$FIXTURE_DIR/AndroidManifest.xml"   --java "$WORK_DIR/gen"   --min-sdk-version 23   --target-sdk-version 34   --auto-add-overlay   -o "$WORK_DIR/fixture-unsigned.apk"   "$WORK_DIR/compiled-res.zip"

echo "==> Compiling Java sources"
mapfile -t JAVA_SOURCES < <(
  find "$FIXTURE_DIR/src" "$WORK_DIR/gen" -name '*.java' -print
)
javac   -source 8   -target 8   -classpath "$ANDROID_JAR"   -d "$WORK_DIR/classes"   "${JAVA_SOURCES[@]}"

echo "==> Creating classes.dex"
mapfile -t CLASS_FILES < <(
  find "$WORK_DIR/classes" -name '*.class' -print
)
"$D8"   --lib "$ANDROID_JAR"   --min-api 23   --output "$WORK_DIR/dex"   "${CLASS_FILES[@]}"

(
  cd "$WORK_DIR/dex"
  zip -q -j "$WORK_DIR/fixture-unsigned.apk" classes.dex
)

echo "==> Signing original fixture"
java -jar "$SIGNER_JAR"   --apks "$WORK_DIR/fixture-unsigned.apk"   --out "$WORK_DIR/signed-original"   --verbose

SIGNED_ORIGINAL="$(find "$WORK_DIR/signed-original" -maxdepth 1 -type f -name '*.apk' | head -n 1)"
if [[ -z "$SIGNED_ORIGINAL" ]]; then
  echo "Signer did not produce an APK." >&2
  exit 1
fi

java -jar "$SIGNER_JAR"   --apks "$SIGNED_ORIGINAL"   --onlyVerify   --verbose

echo "==> Decoding with Apktool"
java -jar "$APKTOOL_JAR" d   "$SIGNED_ORIGINAL"   -o "$WORK_DIR/decoded"   -f

MAIN_SMALI="$(find "$WORK_DIR/decoded" -path '*/com/example/obfuscatemefixture/MainActivity.smali' | head -n 1)"
if [[ -z "$MAIN_SMALI" ]]; then
  echo "MainActivity.smali was not produced by Apktool." >&2
  exit 1
fi

grep -q 'Lcom/example/obfuscatemefixture/MainActivity;' "$MAIN_SMALI"
grep -q 'xmlClicked' "$MAIN_SMALI"
grep -q 'MainActivity' "$WORK_DIR/decoded/AndroidManifest.xml"
grep -q 'android:onClick="xmlClicked"' "$WORK_DIR/decoded/res/layout/activity_main.xml"

echo "==> Rebuilding decoded APK"
java -jar "$APKTOOL_JAR" b   "$WORK_DIR/decoded"   -o "$WORK_DIR/fixture-rebuilt-unsigned.apk"

echo "==> Signing rebuilt APK"
java -jar "$SIGNER_JAR"   --apks "$WORK_DIR/fixture-rebuilt-unsigned.apk"   --out "$WORK_DIR/signed-rebuilt"   --verbose

SIGNED_REBUILT="$(find "$WORK_DIR/signed-rebuilt" -maxdepth 1 -type f -name '*.apk' | head -n 1)"
if [[ -z "$SIGNED_REBUILT" ]]; then
  echo "Signer did not produce a rebuilt signed APK." >&2
  exit 1
fi

echo "==> Verifying rebuilt APK"
java -jar "$SIGNER_JAR"   --apks "$SIGNED_REBUILT"   --onlyVerify   --verbose

if command -v apkanalyzer >/dev/null 2>&1; then
  TARGET_SDK="$(apkanalyzer manifest target-sdk "$SIGNED_REBUILT")"
  if [[ "$TARGET_SDK" != "34" ]]; then
    echo "Expected target SDK 34, got $TARGET_SDK" >&2
    exit 1
  fi
fi

echo
echo "Android 14/API 34 integration test passed."
echo "Original signed APK: $SIGNED_ORIGINAL"
echo "Rebuilt signed APK:  $SIGNED_REBUILT"
