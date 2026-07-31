package com.panda.e2e;

import com.sun.jna.Library;
import com.sun.jna.Native;
import org.springframework.stereotype.Component;

/**
 * Panda client for BODY firmware e2e testing.
 * Loads libpanda_body.dylib and provides JNA access to body-specific commands.
 */
@Component
public class BodyPandaClient {

    public interface BodyPandaLib extends Library {
        String libPath = System.getProperty("user.dir") + "/src/test/c/libpanda_body.dylib";
        BodyPandaLib INSTANCE = Native.load(libPath, BodyPandaLib.class);

        /** Send a control request to comms_control_handler. Returns response length. */
        int jna_body_control_write(int request, int param1, int param2);

        /** Read one byte from the response buffer (filled by last control_write). */
        int jna_body_get_resp_byte(int index);

        /** Read motor target globals */
        int jna_body_get_rpm_left();
        int jna_body_get_rpm_right();
        int jna_body_get_enable_motors();

        /** Get hardware type (0xB1 for body) */
        int jna_body_get_hw_type();

        /** Initialize key firmware state (called once per test) */
        void jna_panda_init();
    }

    /**
     * Initialize the body firmware state. Must be called before tests.
     */
    public void init() {
        BodyPandaLib.INSTANCE.jna_panda_init();
    }

    /**
     * Send a USB control command and return the full response as bytes.
     */
    public byte[] controlWriteWithResponse(int request, int param1, int param2) {
        int len = BodyPandaLib.INSTANCE.jna_body_control_write(request, param1, param2);
        byte[] resp = new byte[len];
        for (int i = 0; i < len; i++) {
            resp[i] = (byte) BodyPandaLib.INSTANCE.jna_body_get_resp_byte(i);
        }
        return resp;
    }

    /**
     * Send a USB control command to the body firmware.
     */
    public void controlWrite(int request, int param1, int param2) {
        BodyPandaLib.INSTANCE.jna_body_control_write(request, param1, param2);
    }

    /**
     * Set motor speed (command 0xb3).
     */
    public void setMotorSpeed(int leftRpm, int rightRpm) {
        BodyPandaLib.INSTANCE.jna_body_control_write(0xb3, leftRpm, rightRpm);
    }

    /**
     * Enable/disable motors (command 0xb4).
     */
    public void setMotorEnable(boolean enable) {
        BodyPandaLib.INSTANCE.jna_body_control_write(0xb4, enable ? 1 : 0, 0);
    }

    public int getRpmLeft() {
        return BodyPandaLib.INSTANCE.jna_body_get_rpm_left();
    }

    public int getRpmRight() {
        return BodyPandaLib.INSTANCE.jna_body_get_rpm_right();
    }

    public boolean isMotorEnabled() {
        return BodyPandaLib.INSTANCE.jna_body_get_enable_motors() != 0;
    }

    /**
     * Get hardware type via command 0xc1.
     */
    public int getHardwareType() {
        byte[] resp = controlWriteWithResponse(0xc1, 0, 0);
        return resp.length > 0 ? Byte.toUnsignedInt(resp[0]) : -1;
    }

    /**
     * Read hardware type directly from the global (without sending command).
     */
    public int getHwType() {
        return BodyPandaLib.INSTANCE.jna_body_get_hw_type();
    }

    /**
     * Get firmware version via command 0xd6.
     */
    public String getVersion() {
        byte[] resp = controlWriteWithResponse(0xd6, 0, 0);
        // Response is gitversion bytes (null-terminated string)
        return new String(resp, 0, resp.length - 1);  // skip trailing null
    }

    /**
     * Get health packet version hashes via command 0xdd.
     */
    public long[] getVersionHashes() {
        byte[] resp = controlWriteWithResponse(0xdd, 0, 0);
        if (resp.length < 8) return new long[]{0, 0};
        // Two uint32 values (little-endian)
        long healthVer = Byte.toUnsignedInt(resp[0])
                | ((long) Byte.toUnsignedInt(resp[1]) << 8)
                | ((long) Byte.toUnsignedInt(resp[2]) << 16)
                | ((long) Byte.toUnsignedInt(resp[3]) << 24);
        long canVer = Byte.toUnsignedInt(resp[4])
                | ((long) Byte.toUnsignedInt(resp[5]) << 8)
                | ((long) Byte.toUnsignedInt(resp[6]) << 16)
                | ((long) Byte.toUnsignedInt(resp[7]) << 24);
        return new long[]{healthVer, canVer};
    }
}

