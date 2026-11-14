// SPDX-License-Identifier: GPL-3.0-or-later
package mapplebox.cobblemonios;

import java.io.ByteArrayOutputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.lang.instrument.ClassFileTransformer;
import java.lang.instrument.Instrumentation;
import java.nio.file.FileSystemException;
import java.nio.file.LinkOption;
import java.nio.file.NoSuchFileException;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.security.ProtectionDomain;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

/**
 * Java agent that lets Cobblemon's Showdown battle engine start on iOS.
 *
 * <p>The problem: the iOS app sandbox denies lstat() on "/", "/var" and "/private" (EPERM).
 * Path.toRealPath(LinkOption.NOFOLLOW_LINKS) lstat()s every path component from the root, so on
 * iOS it throws for every path. Cobblemon's GraalJS file system guard uses exactly that call, the
 * guard fails, Showdown never starts and the game waits forever on a black screen.
 *
 * <p>The fix: in classes under {@code com/cobblemon/} (and Truffle's polyglot file systems), rewrite
 * {@code invokeinterface java/nio/file/Path.toRealPath([LinkOption;)} into
 * {@code invokestatic CobblemonIosFix.toRealPath(Path, LinkOption[])} plus two nops. Same stack
 * effect and same code length, so offsets and the StackMapTable stay valid. No ASM: we append six
 * constant pool entries and patch the bytes in place.
 *
 * <p>The helper first makes the original call. Only if iOS refuses it with a FileSystemException
 * (but not NoSuchFileException) it falls back to toRealPath() without options, which uses
 * realpath(3) and works inside the sandbox. On other systems nothing changes.
 *
 * <p>Usage: {@code -javaagent:<path>/cobblemon-ios-fix.jar} in the launcher's JVM arguments.
 */
public final class CobblemonIosFix {
    private CobblemonIosFix() {}

    static final String TAG = "[CobblemonIosFix] ";
    static final String HELPER = "mapplebox/cobblemonios/CobblemonIosFix";
    static final String OWNER = "java/nio/file/Path";
    static final String NAME = "toRealPath";
    static final String DESC = "([Ljava/nio/file/LinkOption;)Ljava/nio/file/Path;";
    static final String NEW_DESC = "(Ljava/nio/file/Path;[Ljava/nio/file/LinkOption;)Ljava/nio/file/Path;";

    /** Called by the patched Cobblemon code instead of Path.toRealPath(options). */
    public static Path toRealPath(Path path, LinkOption[] options) throws IOException {
        try {
            return path.toRealPath(options);
        } catch (FileSystemException e) {
            if (e instanceof NoSuchFileException) throw e;
            return path.toRealPath();
        }
    }

    public static void premain(String args, Instrumentation inst) {
        inst.addTransformer(new ClassFileTransformer() {
            @Override
            public byte[] transform(ClassLoader loader, String className, Class<?> cls,
                                    ProtectionDomain pd, byte[] bytes) {
                if (!shouldPatch(className)) return null;
                exposeToGame(loader);
                try {
                    byte[] out = patch(bytes);
                    if (out != null) log("patched toRealPath in " + className);
                    return out;
                } catch (Throwable t) {
                    log("could not patch " + className + ": " + t);
                    return null;
                }
            }
        });
        log("installed");
    }

    /**
     * Cobblemon's own classes, plus GraalVM Truffle's polyglot file systems. Cobblemon 1.7.x
     * relocates Truffle under com/cobblemon/, 1.8.x ships it unrelocated as a nested jar.
     */
    static boolean shouldPatch(String className) {
        return className != null
                && (className.startsWith("com/cobblemon/")
                || className.startsWith("com/oracle/truffle/polyglot/FileSystems"));
    }

    static void log(String s) {
        System.out.println(TAG + s);
    }

    private static volatile boolean exposed;

    /**
     * Fabric's Knot class loader hides class path entries that are not part of the game
     * ("class path isolation"), so patched Cobblemon classes could not see this helper class.
     * On the first Cobblemon class load, add this jar to the game class path through Fabric's own
     * launcher API. This also makes the Narrator$InitializeException class in this jar visible.
     */
    static synchronized void exposeToGame(ClassLoader loader) {
        if (exposed || loader == null) return;
        exposed = true;
        try {
            Path jar = Paths.get(CobblemonIosFix.class.getProtectionDomain().getCodeSource().getLocation().toURI());
            Class<?> base = Class.forName("net.fabricmc.loader.impl.launch.FabricLauncherBase", true, loader);
            Object launcher = base.getMethod("getLauncher").invoke(null);
            Class<?> api = Class.forName("net.fabricmc.loader.impl.launch.FabricLauncher", true, loader);
            api.getMethod("addToClassPath", Path.class, String[].class).invoke(launcher, jar, new String[0]);
            log("added to the game class path: " + jar.getFileName());
        } catch (Throwable t) {
            log("could not add the agent jar to the game class path: " + t);
        }
    }

    static int u1(byte[] b, int p) { return b[p] & 0xff; }
    static int u2(byte[] b, int p) { return ((b[p] & 0xff) << 8) | (b[p + 1] & 0xff); }
    static int u4(byte[] b, int p) { return (u2(b, p) << 16) | u2(b, p + 2); }

    /** Returns the patched class file, or null if the class has no matching call. */
    static byte[] patch(byte[] in) throws IOException {
        if (in.length < 10 || u4(in, 0) != 0xCAFEBABE) return null;
        int cpCount = u2(in, 8);
        if (cpCount + 6 > 0xFFFF) return null;
        int[] tag = new int[cpCount];
        int[] off = new int[cpCount];
        Map<Integer, String> utf8 = new HashMap<>();
        int p = 10;
        for (int i = 1; i < cpCount; i++) {
            int t = u1(in, p);
            tag[i] = t;
            off[i] = p;
            switch (t) {
                case 1: {
                    int len = u2(in, p + 1);
                    utf8.put(i, new String(in, p + 3, len, "UTF-8")); // fine for the ASCII names we compare
                    p += 3 + len;
                    break;
                }
                case 3: case 4: case 9: case 10: case 11: case 12: case 17: case 18: p += 5; break;
                case 5: case 6: p += 9; i++; break;
                case 7: case 8: case 16: case 19: case 20: p += 3; break;
                case 15: p += 4; break;
                default: throw new IOException("unknown constant pool tag " + t + " at " + i);
            }
        }
        int cpEnd = p;

        // InterfaceMethodref entries that point to Path.toRealPath(LinkOption[])
        Set<Integer> targets = new HashSet<>();
        for (int i = 1; i < cpCount; i++) {
            if (tag[i] != 11) continue;
            int classIdx = u2(in, off[i] + 1), natIdx = u2(in, off[i] + 3);
            if (tag[classIdx] != 7 || tag[natIdx] != 12) continue;
            String owner = utf8.get(u2(in, off[classIdx] + 1));
            String name = utf8.get(u2(in, off[natIdx] + 1));
            String desc = utf8.get(u2(in, off[natIdx] + 3));
            if (OWNER.equals(owner) && NAME.equals(name) && DESC.equals(desc)) targets.add(i);
        }
        if (targets.isEmpty()) return null;

        int base = cpCount;            // new entries: base .. base+5
        int newMethodref = base + 5;
        byte[] body = in.clone();      // patched in place, offsets after the constant pool stay the same
        int patched = 0;

        p = cpEnd + 6;                 // access_flags, this_class, super_class
        int ifCount = u2(in, p); p += 2 + 2 * ifCount;
        int fieldCount = u2(in, p); p += 2;
        for (int f = 0; f < fieldCount; f++) {
            p += 6;
            int ac = u2(in, p); p += 2;
            for (int a = 0; a < ac; a++) p += 6 + u4(in, p + 2);
        }
        int methodCount = u2(in, p); p += 2;
        for (int m = 0; m < methodCount; m++) {
            p += 6;
            int ac = u2(in, p); p += 2;
            for (int a = 0; a < ac; a++) {
                String an = utf8.get(u2(in, p));
                int alen = u4(in, p + 2);
                if ("Code".equals(an)) {
                    int codeLen = u4(in, p + 10);
                    int cs = p + 14, ce = cs + codeLen;
                    for (int c = cs; c + 4 < ce; c++) {
                        // invokeinterface #idx, count=2, 0
                        if (u1(in, c) == 0xB9 && targets.contains(u2(in, c + 1))
                                && u1(in, c + 3) == 2 && u1(in, c + 4) == 0) {
                            body[c] = (byte) 0xB8;                     // invokestatic
                            body[c + 1] = (byte) (newMethodref >> 8);
                            body[c + 2] = (byte) newMethodref;
                            body[c + 3] = 0;                           // nop
                            body[c + 4] = 0;                           // nop
                            patched++;
                            c += 4;
                        }
                    }
                }
                p += 6 + alen;
            }
        }
        if (patched == 0) return null;

        ByteArrayOutputStream bos = new ByteArrayOutputStream(in.length + 200);
        DataOutputStream out = new DataOutputStream(bos);
        out.write(body, 0, 8);
        out.writeShort(cpCount + 6);
        out.write(body, 10, cpEnd - 10);
        out.writeByte(1); out.writeUTF(HELPER);                                  // base     Utf8
        out.writeByte(7); out.writeShort(base);                                  // base+1   Class
        out.writeByte(1); out.writeUTF(NAME);                                    // base+2   Utf8
        out.writeByte(1); out.writeUTF(NEW_DESC);                                // base+3   Utf8
        out.writeByte(12); out.writeShort(base + 2); out.writeShort(base + 3);   // base+4   NameAndType
        out.writeByte(10); out.writeShort(base + 1); out.writeShort(base + 4);   // base+5   Methodref
        out.write(body, cpEnd, body.length - cpEnd);
        out.flush();
        return bos.toByteArray();
    }
}
