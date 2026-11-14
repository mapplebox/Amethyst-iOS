# cobblemon-ios-fix

A tiny Java agent (6 KB, no dependencies) that lets **Cobblemon** start its battle engine
(Showdown) when Minecraft Java runs on an iPhone through Amethyst.

Without it, a Cobblemon modpack loads all mods and then stays on a **black screen** forever.

## What it fixes and why

1. **Showdown never starts (black screen).**
   The iOS app sandbox does not let apps run `lstat()` on `/`, `/var` or `/private`.
   Java's `Path.toRealPath(LinkOption.NOFOLLOW_LINKS)` checks every folder from the root down,
   so on iOS it fails for every path. Cobblemon's GraalJS file system guard uses exactly that call,
   the guard fails, and the client waits for Showdown forever.
   The agent rewrites that call in Cobblemon's classes (and in Truffle's polyglot file systems)
   to a helper. The helper tries
   the original call first and, only if iOS refuses it, uses `toRealPath()` without options
   (that one uses `realpath(3)` and works in the sandbox). On a PC nothing changes.
   It patches bytecode without ASM: six constant pool entries are appended and the
   `invokeinterface` is replaced by `invokestatic` + 2 `nop`s, so code offsets stay the same.
2. **`NoClassDefFoundError: com/mojang/text2speech/Narrator$InitializeException`.**
   Amethyst ships its own stub of Mojang's text2speech library, and that stub has no
   `Narrator.InitializeException`. The jar contains an empty exception class with that name
   (four constructors, written from scratch, no Mojang code). The agent adds itself to Fabric's
   game class path, so the game can find it.

Patch sites found by running the patcher offline over the Cobblemon jars
(Cobblemon's Showdown file system guard plus GraalVM Truffle's polyglot file systems; Cobblemon 1.7.x
relocates Truffle under `com/cobblemon/`, 1.8.x ships it as a nested jar):

| Cobblemon | calls patched |
|---|---|
| 1.7.3+1.21.1 | 3 (`GraalShowdownService$createContext$1`, 2 relocated Truffle `FileSystems` classes) |
| 1.8.4+1.21.1 | 3 (`GraalShowdownService$createContext$1`, 2 Truffle `FileSystems` classes in `truffle-api-22.3.0.jar`) |

**Tested on a device:** iPhone Duo, iOS 27.2, Amethyst from this fork, CobbleBox modpack
(Fabric, Minecraft 1.21.1, Cobblemon 1.7.3, 189 mods in Mod Menu), November 2026.
Cobblemon 1.8.4 was only checked offline (the calls are found and patched), not played on a device.
The tested agent build filtered on `com/cobblemon/` only; the Truffle prefix was added afterwards so
1.8.x gets the same three patch sites that 1.7.3 got on the device.

## Install

1. Copy `cobblemon-ios-fix.jar` to the Amethyst folder in the Files app:
   **On My iPhone > Amethyst > agent > cobblemon-ios-fix.jar** (create the `agent` folder).
2. In Amethyst, edit the profile of your modpack and add to **JVM Launch arguments**
   (in this fork the JVM starts inside the modpack folder
   `instances/default/custom_gamedir/<pack>`, so the path goes up four levels):

   ```
   -javaagent:../../../../agent/cobblemon-ios-fix.jar
   ```

3. Start the game. `latestlog.txt` shows lines starting with `[CobblemonIosFix]`, for example
   `[CobblemonIosFix] patched toRealPath in com/cobblemon/...`.

Other iOS fixes a big Cobblemon pack may need (not part of this jar) are in the guide linked
from the main README of this fork.

If Showdown still hangs after an earlier failed start, delete (or rename) the half-unpacked
`showdown` folder in the modpack folder. Cobblemon unpacks it again on the next start.

## Build

Needs a JDK 8 or newer:

```sh
./build.sh
```

It compiles to Java 8 bytecode and writes `cobblemon-ios-fix.jar`. The prebuilt jar in this folder
was built with Azul Zulu 8 (8.0.512) and has this SHA-256:

```
a715860b45b923909e026347be7fb6475c28ff51f6fa2021cd2706554f8f942a
```

## License

GPL-3.0-or-later, like the rest of this repository. The agent is our own code.
`narrator-stub/` only exists so `javac` can compile the nested exception class; the build
packages `Narrator$InitializeException.class` alone, never the `Narrator` interface.
Minecraft and text2speech are Mojang's. Cobblemon is by the Cobblemon team. This project is not
affiliated with either.
