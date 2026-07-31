package com.panda.e2e;

import com.sun.jna.Library;
import com.sun.jna.Native;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;

/**
 * Panda client for BODY firmware e2e testing.
 * Loads libpanda_body.dylib and provides JNA access to body-specific commands.
 * Follows the same jfactory + DAL + reloadLibrary pattern as PandaClient.
 */
@Component
public class BodyPandaClient {

    // ---- JNA interface (no static INSTANCE — reloaded per test) ----

    public interface BodyPandaLib extends Library {
        int jna_body_control_write(int request, int param1, int param2);
        int jna_body_get_resp_byte(int index);
        int jna_body_get_rpm_left();
        int jna_body_get_rpm_right();
        int jna_body_get_enable_motors();
        int jna_body_get_hw_type();
        void jna_panda_init();
    }

    // ---- Inner data classes (used by jfactory specs) ----

    public static class BodyControlRequest {
        public byte request;
        public short param1, param2;
        public short length;
    }

    // ---- Library lifecycle (mirrors PandaClient reloadLibrary pattern) ----

    private static final String ORIGINAL_LIB_PATH =
            System.getProperty("user.dir") + "/src/test/c/libpanda_body.dylib";
    private BodyPandaLib lib = Native.load(ORIGINAL_LIB_PATH, BodyPandaLib.class);

    private void reloadLibrary() {
        try {
            Path original = Path.of(ORIGINAL_LIB_PATH);
            Path temp = Files.createTempFile("libpanda_body_", ".dylib");
            Files.copy(original, temp, StandardCopyOption.REPLACE_EXISTING);
            temp.toFile().deleteOnExit();
            lib = Native.load(temp.toAbsolutePath().toString(), BodyPandaLib.class);
            lib.jna_panda_init();
        } catch (IOException e) {
            throw new RuntimeException("Failed to reload body native library", e);
        }
    }

    public void clearAll() {
        reloadLibrary();
    }

    // ---- DAL-compatible accessors (used by Then body control data should be:) ----

    public int getRpmLeft()           { return lib.jna_body_get_rpm_left(); }
    public int getRpmRight()          { return lib.jna_body_get_rpm_right(); }
    public boolean isMotorEnabled()   { return lib.jna_body_get_enable_motors() != 0; }
    public int getHwType()            { return lib.jna_body_get_hw_type(); }

    // ---- Public API ----

    /**
     * Send a USB control command — the jfactory entry point.
     * Calls the C-side comms_control_handler with the decoded request.
     */
    public void controlWrite(byte request, short param1, short param2, short length) {
        lib.jna_body_control_write(
                Byte.toUnsignedInt(request), (int) param1, (int) param2);
    }
}
