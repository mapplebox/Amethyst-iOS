# Amethyst-iOS, iOS fixes branch (mapplebox fork)

This is a fork of [AngelAuraMC/Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS), the Minecraft: Java Edition launcher for iOS.
All credit for Amethyst goes to the Amethyst team and its contributors (see below). The license stays **GPL-3.0**.

Branch `mapplebox/ios-fixes` = upstream `main` at `f98c413` plus a few small changes we needed to run a big Cobblemon modpack (189 mods) on an iPhone Duo with iOS 27.2:

| Change | Why |
|---|---|
| **Import local `.mrpack` files** (Share / Open in Amethyst, or "Import .mrpack" in the modpack installer) | Modpacks that are not on Modrinth, or a specific version you exported yourself |
| **Ignore the iOS 27 virtual touchscreen mouse** | iOS 27 reports a virtual `GCMouse`, Amethyst then hid the on-screen controls |
| **Start the JVM inside the modpack folder** (`chdir` + `realpath` of the profile game directory) | Working directory and `user.dir` differed for Modrinth packs (`./custom_gamedir/<pack>`), Cobblemon unpacked Showdown into one folder and read it from the other |
| [`cobblemon-ios-fix/`](cobblemon-ios-fix/) java agent | Cobblemon's Showdown battle engine hangs on iOS (`toRealPath(NOFOLLOW_LINKS)` is denied by the sandbox), plus a missing `Narrator$InitializeException` class |

Tested on: iPhone Duo, iOS 27.2, JIT via StikDebug, renderer ANGLE, 4937 MB RAM for Java, November 2026. Nothing else was tested, so other devices and iOS versions may behave differently.

Known issue: "Choose from Files..." in the import sheet can hang inside the app. Use Share / Open in, or put the `.mrpack` into On My iPhone > Amethyst and pick it from the list.

**Step-by-step guides** (JIT, RAM, JVM flags, every fix with copy-paste values):
- English: https://mapplebox.com/minecraft-java-cobblemon-iphone-duo/
- Deutsch: https://mapplebox.de/minecraft-java-cobblemon-iphone-duo/

### No downloads, build it yourself

We don't publish IPAs of this fork. You build it yourself, two ways:

- **On a Mac:** see "Build" below.
- **Without a Mac:** fork this repo, enable Actions in your fork, then run Actions > "Unsigned IPA (fork)" > Run workflow. It builds a fake-signed IPA on a GitHub-hosted Mac; download it from the finished run. Your sideloading app (SideStore, AltStore, ...) signs it with your own Apple account. This workflow has not been run by us yet.

### Build

On a Mac with Apple silicon and Xcode:

```sh
brew install cmake ldid wget make
# JDK 8 is needed as the build JDK, e.g. Azul Zulu 8 for arm64
gmake -j package PLATFORM=2 BOOTJDK=/path/to/zulu8/Contents/Home/bin
# -> artifacts/org.angelauramc.amethyst-*-ios.ipa (fake-signed)
```

To install it with your own development profile, re-sign every Mach-O in the app with an entitlements file that contains your team's `application-identifier`, `get-task-allow` (needed for JIT through a debugger), `com.apple.developer.kernel.increased-memory-limit` and `com.apple.developer.kernel.extended-virtual-addressing`. Turn the last two on as capabilities for your App ID first.

Not affiliated with Mojang, Microsoft, the Cobblemon team or AngelAuraMC.

---

# Angel Aura Amethyst (iOS)
[![Development build](https://github.com/AngelAuraMC/Amethyst-iOS/actions/workflows/development.yml/badge.svg?branch=main)](https://github.com/AngelAuraMC/Amethyst-iOS/actions/workflows/development.yml)
[![Crowdin](https://badges.crowdin.net/angelauramc/localized.svg)](https://crowdin.com/project/angelauramc)
[![Discord](https://img.shields.io/discord/724163890803638273.svg?label=&logo=discord&logoColor=ffffff&color=7389D8&labelColor=6A7EC2)](https://discord.gg/5ptqkyZxEy)



## Introduction
Amethyst is a Minecraft: Java Edition launcher for Android, iOS, and iPadOS, based off of zhuowei's [Boardwalk](https://github.com/zhuowei/Boardwalk) project.
* Supports most versions of Minecraft: Java Edition, from the very first beta to the newest snapshots.
* Supports Forge, Fabric, OptiFine, and Quilt for you to customize the experience with supported mods.
* Includes customizable on-screen controls, keyboard and mouse support, and game controller support.
* Optimized for jailbroken and TrollStore devices to enable better capabilities.
* Microsoft account and demo mode support for logging into Minecraft.
* ...and much more!

This repository contains the code for our iOS and iPadOS port of Amethyst. Looking for [Android?](https://github.com/AngelAuraMC/Amethyst-Android)

## Getting started with Amethyst
The [Amethyst wiki](https://wiki.angelauramc.dev/wiki/getting_started/INSTALL.html#ios) has extensive documentation on how to install, set up, and play! For those who wish to install quickly, here's the basics:

### Requirements
At the minimum, you'll need one of the following devices on **iOS 14.0** and later:
- iPhone 6s and later
- iPad (5th generation) and later
- iPad Air (2nd generation) and later
- iPad mini (4th generation) and later
- iPad Pro (all models)
- iPod touch (7th generation)

However, we recommend one of the following devices on **iOS 14.0** and later:
- iPhone XS and later, excluding iPhone XR and iPhone SE (2nd generation)
- iPad (10th generation) and later
- iPad Air (4th generation) and later
- iPad mini (6th generation) and later
- iPad Pro (all models, except for 9.7-inch)

Recommended devices provide a smoother and more enjoyable gameplay experience compared to other supported devices.
- iOS 17.x and iOS 18.x is supported. However, a computer is required. For more information, please check out [the official wiki](https://wiki.angelauramc.dev/wiki/faq/ios/JIT.html#what-are-the-methods-to-enable-jit)

### Setting up to sideload
Amethyst can be sideloaded in many ways. Our recommended solution is to install [TrollStore](https://github.com/opa334/TrollStore) if your iOS version supports it. Installing with TrollStore allows you to permanently sign the application, automatically enable JIT, and increase memory limits.

If you cannot, [AltStore](https://altstore.io) and [SideStore](https://sidestore.io) are your next best options.
- Signing services that do not use your UDID (and use distribution certificates) are not supported, as Amethyst requires capabilities they do not allow. However, if you do managed to gain access to a Development certificate, due to it having the necessary entitlement (being com.apple.security.get-task-allow) to attach a debugger to the running process (enabling JIT), you may use a Development certificate.
  
- Only install sideloading software and Amethyst from trusted sources. We are not responsible for any harm caused by using unofficial software.
- Jailbreaks also benefit from permenant signing, autoJIT, and increased memory limits. However, we do not recommend them on devices intended for regular use.

### Installing Amethyst
#### Release build (TrollStore)
1. Download an IPA of Amethyst in [Releases](https://github.com/AngelAuraMC/Amethyst-iOS/releases).
2. Open the package in TrollStore using the share menu.

#### Release build (AltStore/SideStore trusted source)
These builds will be available soon, stay tuned.

#### Nightly builds
*These builds can contain game-breaking bugs. Use with caution.*
1. Download an IPA build of Amethyst in the [Actions tab](https://github.com/AngelAuraMC/Amethyst-iOS/actions).
2. Open the downloaded IPA in your sideloading app to install.

#### Nightly builds (AltStore/SideStore trusted sources)
These builds will be available soon, stay tuned.

### Enabling JIT
Amethyst makes use of **just-in-time compilation**, or JIT, to provide usable speeds for the end user. JIT is not supported on iOS without the application being debugged, so workarounds are required to enable it. You can use this chart to determine the best solution for you and your setup.
| Application         | AltStore | SideStore | StikDebug | TrollStore | Jitterbug          | Jailbroken |
|---------------------|----------|-----------|-----------|------------|--------------------|------------|
| Requires ext-device | Yes      | Yes (#)   | Yes (#)   | No         | If VPN unavailable | No         |
| Requires Wi-Fi      | Yes      | Yes (#)   | Yes (#)   | No         | Yes                | No         |
| Auto enabled        | Yes (*)  | No        | Yes       | Yes        | No                 | Yes        |

(*) AltServer running on the local network is required.
(#) Only the first time.

## Contributors
Amethyst is amazing, and surprisingly stable, and it wouldn't be this way without the commmunity that helped and contribute to the project! Some notable names:

@crystall1nedev - Project manager, iOS port developer  
@khanhduytran0 - iOS port developer  
@artdeell  
@Mathius-Boulay  
@zhuowei  
@jkcoxson   
@Diatrus 

## Third party components and their licenses
- [Caciocavallo](https://github.com/PojavLauncherTeam/caciocavallo): [GNU GPLv2 License](https://github.com/PojavLauncherTeam/caciocavallo/blob/master/LICENSE).
- [jsr305](https://code.google.com/p/jsr-305): [3-Clause BSD License](http://opensource.org/licenses/BSD-3-Clause).
- [Boardwalk](https://github.com/zhuowei/Boardwalk): [Apache 2.0 License](https://github.com/zhuowei/Boardwalk/blob/master/LICENSE) 
- [GL4ES](https://github.com/ptitSeb/gl4es) by @lunixbochs @ptitSeb: [MIT License](https://github.com/ptitSeb/gl4es/blob/master/LICENSE).
- [Mesa 3D Graphics Library](https://gitlab.freedesktop.org/mesa/mesa): [MIT License](https://docs.mesa3d.org/license.html).
- [MetalANGLE](https://github.com/khanhduytran0/metalangle) by @kakashidinho and ANGLE team: [BSD 2.0 License](https://github.com/kakashidinho/metalangle/blob/master/LICENSE).
- [MoltenVK](https://github.com/KhronosGroup/MoltenVK): [Apache 2.0 License](https://github.com/KhronosGroup/MoltenVK/blob/master/LICENSE).
- [openal-soft](https://github.com/kcat/openal-soft): [LGPLv2 License](https://github.com/kcat/openal-soft/blob/master/COPYING).
- [Azul Zulu JDK](https://www.azul.com/downloads/?package=jdk): [GNU GPLv2 License](https://openjdk.java.net/legal/gplv2+ce.html).
- [LWJGL3](https://github.com/PojavLauncherTeam/lwjgl3): [BSD-3 License](https://github.com/LWJGL/lwjgl3/blob/master/LICENSE.md).
- [LWJGLX](https://github.com/PojavLauncherTeam/lwjglx) (LWJGL2 API compatibility layer for LWJGL3): unknown license.
- [DBNumberedSlider](https://github.com/khanhduytran0/DBNumberedSlider): [Apache 2.0 License](https://github.com/immago/DBNumberedSlider/blob/master/LICENSE)
- [fishhook](https://github.com/khanhduytran0/fishhook): [BSD-3 License](https://github.com/facebook/fishhook/blob/main/LICENSE).
- [shaderc](https://github.com/khanhduytran0/shaderc) (used by Vulkan rendering mods): [Apache 2.0 License](https://github.com/google/shaderc/blob/main/LICENSE).
- [NRFileManager](https://github.com/mozilla-mobile/firefox-ios/tree/b2f89ac40835c5988a1a3eb642982544e00f0f90/ThirdParty/NRFileManager): [MPL-2.0 License](https://www.mozilla.org/en-US/MPL/2.0)
- [AltKit](https://github.com/rileytestut/AltKit)
- [UnzipKit](https://github.com/abbeycode/UnzipKit): [BSD-2 License](https://github.com/abbeycode/UnzipKit/blob/master/LICENSE).
- [DyldDeNeuralyzer](https://github.com/xpn/DyldDeNeuralyzer): bypasses Library Validation for loading external runtime
- Thanks to [MCHeads](https://mc-heads.net) for providing Minecraft avatars.
