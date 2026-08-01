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

        int jna_body_is_left_output_enabled();

        int jna_body_is_right_output_enabled();

        int jna_body_get_left_input_target();

        int jna_body_get_right_input_target();

        void jna_body_set_ctrl_mode_req(int mode);

        void jna_body_set_ctrl_type_sel(int ctrlType);

        void jna_body_set_phase_selection(int phaseSelection);

        void jna_body_set_cruise_enabled(int enabled);

        void jna_body_set_cruise_target(int targetRpm);

        void jna_body_set_field_weak_enabled(int enabled);

        void jna_body_set_scheduler_ready(int ready);

        void jna_body_seed_control_mode(int mode);

        void jna_body_set_hall_states(int leftA, int leftB, int leftC, int rightA, int rightB, int rightC);

        void jna_body_set_adc_raw_values(int leftA, int leftC, int leftDc, int rightA, int rightC, int rightDc, int battery);

        int jna_body_get_left_ctrl_mode();

        int jna_body_get_right_ctrl_mode();

        int jna_body_get_left_ctrl_type();

        int jna_body_get_right_ctrl_type();

        int jna_body_get_left_phase_selection();

        int jna_body_get_right_phase_selection();

        int jna_body_get_left_iq();

        int jna_body_get_right_iq();

        int jna_body_get_left_id();

        int jna_body_get_right_id();

        int jna_body_get_left_electrical_angle();

        int jna_body_get_right_electrical_angle();

        int jna_body_get_left_err_code();

        int jna_body_get_right_err_code();

        void jna_panda_init();

        // ---- DotStar LED driver (B10-B12) ----
        void jna_dotstar_init();
        void jna_dotstar_fill(int r, int g, int b);
        void jna_dotstar_show();
        void jna_dotstar_set_pixel(int index, int r, int g, int b);
        void jna_dotstar_set_global_brightness(int brightness);
        void jna_dotstar_run_rainbow(int now_us);
        void jna_dotstar_apply_breathe(int r, int g, int b, int now_us, int cycle_us);

        int jna_dotstar_get_pixel_r(int index);
        int jna_dotstar_get_pixel_g(int index);
        int jna_dotstar_get_pixel_b(int index);
        int jna_dotstar_get_brightness();
        int jna_dotstar_is_initialized();

        // ---- Body CAN (B13-B17) ----
        void jna_body_can_send_motor_speeds(int left, int right);
        void jna_body_can_send_var_values(int ignition, int enableMotors, int fault, int leftZErrcode, int rightZErrcode);
        void jna_body_can_send_body_data(int mcuTempRaw, int battVoltageRaw, int battPercentage, int chargerConnected);
        void jna_body_can_receive_target(int leftRpm, int rightRpm);
        void jna_body_can_periodic(int nowUs, int ignition, int plugCharging);
        void jna_body_set_microsecond_timer(int nowUs);
        int jna_body_get_last_can_cmd_timestamp_us();
        int jna_body_get_can_silent();
        int jna_body_get_can_loopback();
        int jna_body_is_body_safety_mode();
        int jna_body_is_can_transceiver_enabled();
        int jna_body_get_exticr3();
        int jna_body_get_exti_imr1();
        int jna_body_get_exti_rtsr1();
        int jna_body_get_exti_ftsr1();
        int jna_body_get_charging_detect_pupdr();
        int jna_body_get_can_rx_mode();
        int jna_body_get_can_tx_mode();
        int jna_body_get_can_rx_af();
        int jna_body_get_can_tx_af();
        int jna_body_get_obdc_power_mode();
        int jna_body_get_gpu_power_mode();
        int jna_body_get_ignition_output_mode();
        int jna_body_get_obdc_power_output();
        int jna_body_get_gpu_power_output();
        void jna_body_call_tick_handler();
        void jna_body_set_can0_transmit_error_cnt(int count);
        void jna_body_set_can0_ile(int value);
        int jna_body_get_can0_ile();
        int jna_body_get_tick_count();
        int jna_body_get_red_led_output();
        void jna_body_set_charging_detect(int present);
        void jna_body_set_ignition_pressed(int pressed);
        void jna_body_trigger_charging_exti();
        void jna_body_trigger_ignition_exti();
        int jna_body_get_plug_charging();
        int jna_body_get_ignition();
        int jna_body_get_ignition_press_timestamp_us();
        int jna_body_get_ignition_output();
        void jna_body_trigger_tim8_irq();
        int jna_body_get_tim8_sr();
        int jna_body_get_left_dc_pha_a();
        boolean jna_body_can_pop_tx(int[] outAddr, byte[] outReturned, byte[] outData, byte[] outLen, byte[] outExtended, byte[] outFd);
        boolean jna_body_can_pop_rx(int[] outAddr, byte[] outBus, byte[] outRejected, byte[] outReturned, byte[] outData, byte[] outLen, byte[] outExtended, byte[] outFd);
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
    private AdaptiveList<PandaClient.CanMessage> txQueueSnapshot = null;
    private AdaptiveList<PandaClient.CanMessage> rxQueueSnapshot = null;

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
        txQueueSnapshot = null;
        rxQueueSnapshot = null;
    }

    private void invalidateCanSnapshots() {
        txQueueSnapshot = null;
        rxQueueSnapshot = null;
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
    public boolean isLeftOutputEnabled() { return lib.jna_body_is_left_output_enabled() != 0; }
    public boolean isRightOutputEnabled() { return lib.jna_body_is_right_output_enabled() != 0; }
    public int getLeftInputTarget() { return lib.jna_body_get_left_input_target(); }
    public int getRightInputTarget() { return lib.jna_body_get_right_input_target(); }
    public void setCtrlModeReq(int mode) { lib.jna_body_set_ctrl_mode_req(mode); }
    public void setCtrlTypeSel(int ctrlType) { lib.jna_body_set_ctrl_type_sel(ctrlType); }
    public void setPhaseSelection(int phaseSelection) { lib.jna_body_set_phase_selection(phaseSelection); }
    public void setCruiseEnabled(boolean enabled) { lib.jna_body_set_cruise_enabled(enabled ? 1 : 0); }
    public void setCruiseTarget(int targetRpm) { lib.jna_body_set_cruise_target(targetRpm); }
    public void setFieldWeakEnabled(boolean enabled) { lib.jna_body_set_field_weak_enabled(enabled ? 1 : 0); }
    public void setSchedulerReady(boolean ready) { lib.jna_body_set_scheduler_ready(ready ? 1 : 0); }
    public void seedControlMode(int mode) { lib.jna_body_seed_control_mode(mode); }
    public void setHallStates(boolean leftA, boolean leftB, boolean leftC, boolean rightA, boolean rightB, boolean rightC) {
        lib.jna_body_set_hall_states(leftA ? 1 : 0, leftB ? 1 : 0, leftC ? 1 : 0, rightA ? 1 : 0, rightB ? 1 : 0, rightC ? 1 : 0);
    }
    public void setAdcRawValues(int leftA, int leftC, int leftDc, int rightA, int rightC, int rightDc, int battery) {
        lib.jna_body_set_adc_raw_values(leftA, leftC, leftDc, rightA, rightC, rightDc, battery);
    }
    public int getLeftCtrlMode() { return lib.jna_body_get_left_ctrl_mode(); }
    public int getRightCtrlMode() { return lib.jna_body_get_right_ctrl_mode(); }
    public int getLeftCtrlType() { return lib.jna_body_get_left_ctrl_type(); }
    public int getRightCtrlType() { return lib.jna_body_get_right_ctrl_type(); }
    public int getLeftPhaseSelection() { return lib.jna_body_get_left_phase_selection(); }
    public int getRightPhaseSelection() { return lib.jna_body_get_right_phase_selection(); }
    public int getLeftIq() { return lib.jna_body_get_left_iq(); }
    public int getRightIq() { return lib.jna_body_get_right_iq(); }
    public int getLeftId() { return lib.jna_body_get_left_id(); }
    public int getRightId() { return lib.jna_body_get_right_id(); }
    public int getLeftElectricalAngle() { return lib.jna_body_get_left_electrical_angle(); }
    public int getRightElectricalAngle() { return lib.jna_body_get_right_electrical_angle(); }
    public int getLeftErrCode() { return lib.jna_body_get_left_err_code(); }
    public int getRightErrCode() { return lib.jna_body_get_right_err_code(); }

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

    // ---- DotStar LED driver (B10-B12) ----

    public void dotstarFill(int r, int g, int b) { lib.jna_dotstar_fill(r, g, b); }
    public void dotstarShow() { lib.jna_dotstar_show(); }
    public void dotstarSetPixel(int index, int r, int g, int b) { lib.jna_dotstar_set_pixel(index, r, g, b); }
    public void dotstarSetGlobalBrightness(int brightness) { lib.jna_dotstar_set_global_brightness(brightness); }
    public void dotstarRunRainbow(int nowUs) { lib.jna_dotstar_run_rainbow(nowUs); }
    public void dotstarApplyBreathe(int r, int g, int b, int nowUs, int cycleUs) {
        lib.jna_dotstar_apply_breathe(r, g, b, nowUs, cycleUs);
    }

    /**
     * Nested object for DAL property resolution: {@code dotstar.initialized}, {@code dotstar.pixel0R}, etc.
     */
    @Getter
    public class DotstarState {
        public boolean isInitialized() { return lib.jna_dotstar_is_initialized() != 0; }
        public int getBrightness() { return lib.jna_dotstar_get_brightness(); }
        public int getPixel0R() { return lib.jna_dotstar_get_pixel_r(0); }
        public int getPixel0G() { return lib.jna_dotstar_get_pixel_g(0); }
        public int getPixel0B() { return lib.jna_dotstar_get_pixel_b(0); }
        public int getPixel3R() { return lib.jna_dotstar_get_pixel_r(3); }
        public int getPixel3G() { return lib.jna_dotstar_get_pixel_g(3); }
        public int getPixel3B() { return lib.jna_dotstar_get_pixel_b(3); }
        public int getPixel9R() { return lib.jna_dotstar_get_pixel_r(9); }
        public int getPixel9G() { return lib.jna_dotstar_get_pixel_g(9); }
        public int getPixel9B() { return lib.jna_dotstar_get_pixel_b(9); }
    }

    private final DotstarState dotstar = new DotstarState();

    public DotstarState getDotstar() { return dotstar; }

    // ---- Public API ----

    /**
     * Send a USB control command — the jfactory entry point.
     * Calls the C-side comms_control_handler with the decoded request.
     */
    public void controlWrite(byte request, short param1, short param2) {
        invalidateCanSnapshots();
        lib.jna_body_control_write(Byte.toUnsignedInt(request), param1, param2);
    }

    // ---- Body CAN (B13-B17) ----

    public void bodyCanSendMotorSpeeds(int leftRpm, int rightRpm) {
        invalidateCanSnapshots();
        lib.jna_body_can_send_motor_speeds(leftRpm, rightRpm);
    }

    public void bodyCanSendVarValues(boolean ignition, boolean enableMotors, int fault, int leftZErrcode, int rightZErrcode) {
        invalidateCanSnapshots();
        lib.jna_body_can_send_var_values(ignition ? 1 : 0, enableMotors ? 1 : 0, fault, leftZErrcode, rightZErrcode);
    }

    public void bodyCanSendBodyData(int mcuTempRaw, int battVoltageRaw, int battPercentage, boolean chargerConnected) {
        invalidateCanSnapshots();
        lib.jna_body_can_send_body_data(mcuTempRaw, battVoltageRaw, battPercentage, chargerConnected ? 1 : 0);
    }

    public void bodyCanSetMicrosecondTimer(int nowUs) {
        lib.jna_body_set_microsecond_timer(nowUs);
    }

    public void bodyCanReceiveTarget(int leftRpm, int rightRpm) {
        invalidateCanSnapshots();
        lib.jna_body_can_receive_target(leftRpm, rightRpm);
    }

    public void bodyCanPeriodic(int nowUs, boolean ignition, boolean plugCharging) {
        invalidateCanSnapshots();
        lib.jna_body_can_periodic(nowUs, ignition ? 1 : 0, plugCharging ? 1 : 0);
    }

    public void callTickHandler() {
        lib.jna_body_call_tick_handler();
    }

    public void setCan0TransmitErrorCount(int count) {
        lib.jna_body_set_can0_transmit_error_cnt(count);
    }

    public void setCan0Ile(int value) {
        lib.jna_body_set_can0_ile(value);
    }

    public void setChargingDetect(boolean present) {
        lib.jna_body_set_charging_detect(present ? 1 : 0);
    }

    public void setIgnitionPressed(boolean pressed) {
        lib.jna_body_set_ignition_pressed(pressed ? 1 : 0);
    }

    public void triggerChargingExti() {
        lib.jna_body_trigger_charging_exti();
    }

    public void triggerIgnitionExti() {
        lib.jna_body_trigger_ignition_exti();
    }

    public void triggerTim8UpdateInterrupt() {
        lib.jna_body_trigger_tim8_irq();
    }

    @Getter
    public class BodyCanState {
        public boolean isCanSilent() { return lib.jna_body_get_can_silent() != 0; }
        public boolean isCanLoopback() { return lib.jna_body_get_can_loopback() != 0; }
        public boolean isBodySafetyHooksSet() { return lib.jna_body_is_body_safety_mode() != 0; }
        public boolean isCanTransceiverEnabled() { return lib.jna_body_is_can_transceiver_enabled() != 0; }
        public int getLastCanCmdTimestampUs() { return lib.jna_body_get_last_can_cmd_timestamp_us(); }
    }

    private final BodyCanState bodyCan = new BodyCanState();

    public BodyCanState getBodyCan() { return bodyCan; }

    public int getTickCount() { return lib.jna_body_get_tick_count(); }
    public int getExticr3() { return lib.jna_body_get_exticr3(); }
    public int getExtiImr1() { return lib.jna_body_get_exti_imr1(); }
    public int getExtiRtsr1() { return lib.jna_body_get_exti_rtsr1(); }
    public int getExtiFtsr1() { return lib.jna_body_get_exti_ftsr1(); }
    public int getChargingDetectPupdr() { return lib.jna_body_get_charging_detect_pupdr(); }
    public int getCanRxMode() { return lib.jna_body_get_can_rx_mode(); }
    public int getCanTxMode() { return lib.jna_body_get_can_tx_mode(); }
    public int getCanRxAf() { return lib.jna_body_get_can_rx_af(); }
    public int getCanTxAf() { return lib.jna_body_get_can_tx_af(); }
    public int getObdcPowerMode() { return lib.jna_body_get_obdc_power_mode(); }
    public int getGpuPowerMode() { return lib.jna_body_get_gpu_power_mode(); }
    public int getIgnitionOutputMode() { return lib.jna_body_get_ignition_output_mode(); }
    public boolean isObdcPowerOn() { return lib.jna_body_get_obdc_power_output() != 0; }
    public boolean isGpuPowerOn() { return lib.jna_body_get_gpu_power_output() != 0; }
    public int getCan0Ile() { return lib.jna_body_get_can0_ile(); }
    public boolean isRedLedOn() { return lib.jna_body_get_red_led_output() != 0; }
    public boolean isPlugCharging() { return lib.jna_body_get_plug_charging() != 0; }
    public boolean isIgnition() { return lib.jna_body_get_ignition() != 0; }
    public int getIgnitionPressTimestampUs() { return lib.jna_body_get_ignition_press_timestamp_us(); }
    public boolean isIgnitionOutputOn() { return lib.jna_body_get_ignition_output() != 0; }
    public int getTim8Sr() { return lib.jna_body_get_tim8_sr(); }
    public int getLeftDcPhaA() { return lib.jna_body_get_left_dc_pha_a(); }

    public AdaptiveList<PandaClient.CanMessage> getTxQueue() {
        if (txQueueSnapshot != null) {
            return txQueueSnapshot;
        }

        int[] outAddr = new int[1];
        byte[] outReturned = new byte[1];
        byte[] outData = new byte[64];
        byte[] outLen = new byte[1];
        byte[] outExtended = new byte[1];
        byte[] outFd = new byte[1];
        var canMessages = new ArrayList<PandaClient.CanMessage>();

        while (lib.jna_body_can_pop_tx(outAddr, outReturned, outData, outLen, outExtended, outFd)) {
            int len = Byte.toUnsignedInt(outLen[0]);
            byte[] data = new byte[len];
            System.arraycopy(outData, 0, data, 0, len);
            canMessages.add(new PandaClient.CanMessage(outAddr[0], 0, data, false, outReturned[0] != 0,
                    outExtended[0] != 0, outFd[0] != 0));
        }

        txQueueSnapshot = AdaptiveList.staticList(canMessages);
        return txQueueSnapshot;
    }

    public AdaptiveList<PandaClient.CanMessage> getRxQueue() {
        if (rxQueueSnapshot != null) {
            return rxQueueSnapshot;
        }

        int[] outAddr = new int[1];
        byte[] outBus = new byte[1];
        byte[] outRejected = new byte[1];
        byte[] outReturned = new byte[1];
        byte[] outData = new byte[64];
        byte[] outLen = new byte[1];
        byte[] outExtended = new byte[1];
        byte[] outFd = new byte[1];
        var canMessages = new ArrayList<PandaClient.CanMessage>();

        while (lib.jna_body_can_pop_rx(outAddr, outBus, outRejected, outReturned, outData, outLen, outExtended, outFd)) {
            int len = Byte.toUnsignedInt(outLen[0]);
            byte[] data = new byte[len];
            System.arraycopy(outData, 0, data, 0, len);
            canMessages.add(new PandaClient.CanMessage(outAddr[0], Byte.toUnsignedInt(outBus[0]), data,
                    outRejected[0] != 0, outReturned[0] != 0, outExtended[0] != 0, outFd[0] != 0));
        }

        rxQueueSnapshot = AdaptiveList.staticList(canMessages);
        return rxQueueSnapshot;
    }
}
