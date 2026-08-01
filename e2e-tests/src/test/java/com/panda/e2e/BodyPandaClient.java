package com.panda.e2e;

import com.sun.jna.Library;
import com.sun.jna.Native;
import lombok.AllArgsConstructor;
import lombok.Getter;
import org.springframework.stereotype.Component;
import org.testcharm.dal.runtime.AdaptiveList;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;

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

        int jna_body_get_rpm_left();

        int jna_body_get_rpm_right();

        int jna_body_get_enable_motors();

        int jna_body_get_hw_type();

        // ---- Response buffer access (filled by jna_body_control_write) ----
        int jna_body_get_resp_len();

        int jna_body_get_resp_byte(int index);

        // ---- NVIC reset count ----
        int jna_body_get_nvic_reset_count();

        void jna_body_reset_nvic_count();

        // ---- Bootloader mode state ----
        int jna_body_get_enter_bootloader_mode();

        // ---- Signature data preset (for 0xd3/0xd4 signature commands) ----
        void jna_body_set_app_code_len(int len);

        void jna_body_set_signature_chunk(int chunk, byte[] data, int data_len);

        // ---- BLDC motor control ----
        void jna_body_bldc_init();

        int jna_body_get_tim8_cr1();

        int jna_body_get_tim1_cr1();

        int jna_body_get_tim8_arr();

        int jna_body_get_tim1_arr();

        // B9: bldc_step / FOC algorithm
        void jna_bldc_step();

        void jna_body_skip_calibration();

        void jna_body_set_motor_speeds(int left, int right);

        void jna_body_set_enable_motors_val(int enable);

        int jna_body_get_tim8_ccr1();

        int jna_body_get_tim8_ccr2();

        int jna_body_get_tim8_ccr3();

        int jna_body_get_tim1_ccr1();

        int jna_body_get_tim1_ccr2();

        int jna_body_get_tim1_ccr3();

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

    public int getRpmLeft() {
        return lib.jna_body_get_rpm_left();
    }

    public int getRpmRight() {
        return lib.jna_body_get_rpm_right();
    }

    public boolean isMotorEnabled() {
        return lib.jna_body_get_enable_motors() != 0;
    }

    public int getHwType() {
        return lib.jna_body_get_hw_type();
    }

    // ---- Response buffer access ----

    @AllArgsConstructor
    @Getter
    public static class RespBuffer {
        private final AdaptiveList<Byte> bytes;
        private final int len;
    }

    public RespBuffer getRespBuffer() {
        int len = lib.jna_body_get_resp_len();
        var list = new ArrayList<Byte>();
        for (int i = 0; i < len; i++) {
            list.add((byte) lib.jna_body_get_resp_byte(i));
        }
        return new RespBuffer(AdaptiveList.staticList(list), len);
    }

    // ---- NVIC reset count ----

    public int getNvicResetCount() {
        return lib.jna_body_get_nvic_reset_count();
    }

    public void resetNvicCount() {
        lib.jna_body_reset_nvic_count();
    }

    // ---- Bootloader mode state ----

    public int getEnterBootloaderMode() {
        return lib.jna_body_get_enter_bootloader_mode();
    }

    // ---- Signature data preset ----

    public void setAppCodeLen(int len) {
        lib.jna_body_set_app_code_len(len);
    }

    public void setSignatureChunk(int chunk, byte[] data) {
        lib.jna_body_set_signature_chunk(chunk, data, data.length);
    }

    // ---- BLDC motor control (B8) ----

    /**
     * B8: Initialize BLDC/FOC controller, TIM1 and TIM8 for PWM.
     */
    public void bldcInit() {
        lib.jna_body_bldc_init();
    }

    // BIT(0) = TIM_CR1_CEN
    private static final int TIM_CR1_CEN = 1;

    public boolean isLeftTimerEnabled() {
        return (lib.jna_body_get_tim8_cr1() & TIM_CR1_CEN) != 0;
    }

    public boolean isRightTimerEnabled() {
        return (lib.jna_body_get_tim1_cr1() & TIM_CR1_CEN) != 0;
    }

    // ---- BLDC motor control (B9): FOC step ----

    /**
     * B9: Skip ADC calibration phase so bldc_step executes the FOC algorithm.
     */
    public void bldcSkipCalibration() {
        lib.jna_body_skip_calibration();
    }

    /**
     * B9: Execute one FOC step (bldc_step).
     */
    public void bldcStep() {
        lib.jna_bldc_step();
    }

    /**
     * B9: Set motor speed targets and enable motors.
     */
    public void setMotorSpeeds(int leftRpm, int rightRpm, boolean enable) {
        lib.jna_body_set_motor_speeds(leftRpm, rightRpm);
        lib.jna_body_set_enable_motors_val(enable ? 1 : 0);
    }

    public int getTim8Ccr1() { return lib.jna_body_get_tim8_ccr1(); }
    public int getTim8Ccr2() { return lib.jna_body_get_tim8_ccr2(); }
    public int getTim8Ccr3() { return lib.jna_body_get_tim8_ccr3(); }
    public int getTim1Ccr1() { return lib.jna_body_get_tim1_ccr1(); }
    public int getTim1Ccr2() { return lib.jna_body_get_tim1_ccr2(); }
    public int getTim1Ccr3() { return lib.jna_body_get_tim1_ccr3(); }

    /**
     * B9: True if any TIM8 CCR register has a non-zero PWM value.
     */
    public boolean isLeftPwmActive() {
        return getTim8Ccr1() != 0 || getTim8Ccr2() != 0 || getTim8Ccr3() != 0;
    }

    /**
     * B9: True if any TIM1 CCR register has a non-zero PWM value.
     */
    public boolean isRightPwmActive() {
        return getTim1Ccr1() != 0 || getTim1Ccr2() != 0 || getTim1Ccr3() != 0;
    }

    // ---- Public API ----

    /**
     * Send a USB control command — the jfactory entry point.
     * Calls the C-side comms_control_handler with the decoded request.
     */
    public void controlWrite(byte request, short param1, short param2) {
        lib.jna_body_control_write(Byte.toUnsignedInt(request), param1, param2);
    }
}
