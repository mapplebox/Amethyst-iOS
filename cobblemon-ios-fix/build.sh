#!/bin/sh
# Builds cobblemon-ios-fix.jar (Java 8 bytecode, no dependencies).
# Needs a JDK 8 or newer: javac and jar on PATH, or JAVA_HOME set.
set -eu
cd "$(dirname "$0")"

if [ -n "${JAVA_HOME:-}" ]; then BIN="$JAVA_HOME/bin/"; else BIN=""; fi
JAVAC="${BIN}javac"
JAR="${BIN}jar"

# JDK 9+ can target Java 8 with --release; JDK 8 itself is already Java 8.
if "$JAVAC" -version 2>&1 | grep -q 'javac 1\.8'; then
  TARGET="-source 8 -target 8"
else
  TARGET="--release 8"
fi

rm -rf build
mkdir -p build/classes build/stub

# 1. the agent
"$JAVAC" $TARGET -encoding UTF-8 -Xlint:-options -d build/classes \
  src/mapplebox/cobblemonios/CobblemonIosFix.java

# 2. the nested exception class only (the Narrator interface itself is NOT shipped)
"$JAVAC" $TARGET -encoding UTF-8 -Xlint:-options -d build/stub \
  narrator-stub/com/mojang/text2speech/Narrator.java
mkdir -p build/classes/com/mojang/text2speech
cp 'build/stub/com/mojang/text2speech/Narrator$InitializeException.class' build/classes/com/mojang/text2speech/

# 3. jar with the agent manifest
"$JAR" cfm cobblemon-ios-fix.jar MANIFEST.MF -C build/classes .
rm -rf build
echo "built cobblemon-ios-fix.jar"
"$JAR" tf cobblemon-ios-fix.jar
