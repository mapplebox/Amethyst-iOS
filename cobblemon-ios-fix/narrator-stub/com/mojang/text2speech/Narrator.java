// SPDX-License-Identifier: GPL-3.0-or-later
package com.mojang.text2speech;

/**
 * Compile-time stand-in only. The build packages just Narrator$InitializeException.class,
 * never this interface: at runtime the launcher's own Narrator stub stays in charge.
 *
 * Why: Amethyst's text2speech stub (JavaApp/src/launcher/com/mojang/text2speech/Narrator.java)
 * has no nested InitializeException. Minecraft 1.21.1 references it, so a modded client can crash
 * with NoClassDefFoundError: com/mojang/text2speech/Narrator$InitializeException.
 * This is an empty exception class with the same name, written from scratch. No Mojang code.
 */
public interface Narrator {
    class InitializeException extends Exception {
        public InitializeException() {
            super();
        }

        public InitializeException(String message) {
            super(message);
        }

        public InitializeException(Throwable cause) {
            super(cause);
        }

        public InitializeException(String message, Throwable cause) {
            super(message, cause);
        }
    }
}
