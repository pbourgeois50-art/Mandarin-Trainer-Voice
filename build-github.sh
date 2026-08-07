#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT}}"
TOOLS="$SDK/build-tools/36.0.0"
ANDROID_JAR="$SDK/platforms/android-36/android.jar"
SRC="$ROOT/app/src/main"
AAR="$ROOT/deps/aar"
BUILD="$ROOT/build"
rm -rf "$BUILD" "$ROOT/output"
mkdir -p "$BUILD/compiled" "$BUILD/generated" "$BUILD/classes" "$BUILD/dex" "$BUILD/apk-add/lib/arm64-v8a" "$ROOT/output"
"$TOOLS/aapt2" compile --dir "$SRC/res" -o "$BUILD/compiled/resources.zip"
"$TOOLS/aapt2" link -o "$BUILD/base-unsigned.apk" -I "$ANDROID_JAR" --manifest "$SRC/AndroidManifest.xml" --java "$BUILD/generated" -A "$SRC/assets" --min-sdk-version 24 --target-sdk-version 36 --version-code 242 --version-name 2.4.2 "$BUILD/compiled/resources.zip"
mapfile -t JAVA_FILES < <(find "$SRC/java" "$BUILD/generated" -name '*.java' -print)
javac -encoding UTF-8 -source 8 -target 8 -classpath "$ANDROID_JAR:$AAR/classes.jar" -d "$BUILD/classes" "${JAVA_FILES[@]}"
jar --create --file "$BUILD/app-classes.jar" -C "$BUILD/classes" .
"$TOOLS/d8" --min-api 24 --lib "$ANDROID_JAR" --output "$BUILD/dex" "$BUILD/app-classes.jar" "$AAR/classes.jar"
(cd "$BUILD/dex" && zip -q -j "$BUILD/base-unsigned.apk" classes*.dex)
cp "$AAR/jni/arm64-v8a/"*.so "$BUILD/apk-add/lib/arm64-v8a/"
(cd "$BUILD/apk-add" && zip -q -0 -r "$BUILD/base-unsigned.apk" lib)
"$TOOLS/zipalign" -f -P 16 4 "$BUILD/base-unsigned.apk" "$BUILD/aligned.apk"
KEYSTORE="$ROOT/tools/offline-release.keystore"
APK="$ROOT/output/MandarinTrainer-Voice-v2.4.2.apk"
"$TOOLS/apksigner" sign --ks "$KEYSTORE" --ks-key-alias mandarin-offline --ks-pass pass:offline123 --key-pass pass:offline123 --v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true --out "$APK" "$BUILD/aligned.apk"
"$TOOLS/apksigner" verify --verbose --print-certs "$APK"
"$TOOLS/zipalign" -c -P 16 4 "$APK"
sha256sum "$APK" > "$ROOT/output/MandarinTrainer-Voice-v2.4.2-SHA256.txt"
