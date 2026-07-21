package com.panda.e2e;

import com.sun.jna.Library;
import com.sun.jna.Native;
import org.springframework.stereotype.Component;
import org.testcharm.dal.runtime.AdaptiveList;

import java.util.ArrayList;
import java.util.List;

/**
 * Panda client backed by REAL firmware code from board/main.c compiled as .dylib.
 * Goes through the FULL firmware path: comms_control_handler() → set_safety_mode().
 * Used for mutation testing without hardware.
 */
@Component
public class PandaClient {

    public record CanMessage(int address, int bus, byte[] data, boolean rejected) {
    }

    public record RelayCall(boolean a, boolean b) {
    }


    // Simple wrapper needed for DAL-java to distinguish "not called" (null) from "called with value"
    public record CanModeCall(int value) {
    }

    public interface PandaLib extends Library {
        PandaLib INSTANCE = Native.load(
                System.getProperty("user.dir") + "/src/test/c/libpanda.dylib", PandaLib.class);

        void jna_control_write(byte request, short param1, short param2);

        int jna_can_send(int addr, byte bus, byte[] data, byte len);

        int jna_get_safety_tx_blocked();

        boolean jna_can_pop_rx(int[] outAddr, byte[] outBus, byte[] outRejected, byte[] outData, byte[] outLen);

        boolean jna_can_pop_tx(int queueIdx, int[] outAddr, byte[] outData, byte[] outLen);

        void jna_can_clear_all();

        int jna_get_relay_call_count();

        int jna_get_relay_a();

        int jna_get_relay_b();

        void jna_clear_relay_calls();

        int jna_get_can_clear_send_count();

        int jna_get_can_clear_send_x();
        int jna_get_can_clear_send_y();
        void jna_clear_can_clear_send_calls();

        int jna_get_can_mode_call_count();
        int jna_get_can_mode();
        void jna_clear_can_mode_calls();

        // FDCAN register inspection
        void jna_reset_fdcan();

        int jna_get_fdcan_cccr(int canNumber);

        int jna_get_fdcan_ie(int canNumber);

        int jna_get_fdcan_nbtp(int canNumber);

        int jna_get_fdcan_dbtp(int canNumber);

        int jna_get_fdcan_txbc(int canNumber);

        int jna_get_fdcan_rxf0c(int canNumber);

        int jna_get_fdcan_txesc(int canNumber);

        int jna_get_fdcan_rxesc(int canNumber);

        int jna_get_fdcan_gfc(int canNumber);

        int jna_get_fdcan_ile(int canNumber);
        int jna_get_fdcan_ir(int canNumber);

        // Heartbeat state inspection
        int jna_get_heartbeat_counter();
        int jna_get_heartbeat_lost();
        int jna_get_heartbeat_disabled();
        int jna_get_heartbeat_engaged();

        void jna_reset_heartbeat();
        void jna_reset_safety();

        // Health packet inspection
        void jna_read_health_pkt();
        int jna_get_health_uptime();
        int jna_get_health_voltage();
        int jna_get_health_current();
        int jna_get_health_safety_tx_blocked();
        int jna_get_health_safety_rx_invalid();
        int jna_get_health_safety_mode();
        int jna_get_health_safety_param();
        int jna_get_health_heartbeat_lost();

        // Power save state inspection
        int jna_get_power_save_enabled();

        // Alternative experience inspection
        int jna_get_alternative_experience();
        void jna_reset_alternative_experience();

        // Siren state inspection
        int jna_get_siren_enabled();
        void jna_reset_siren();

        // Power-save hardware call tracking
        int jna_get_irq_enable_call_count();
        int jna_get_irq_disable_call_count();
        int jna_get_last_irq_enabled_bus();
        int jna_get_irq_disabled_bus(int bus);
        int jna_get_can_transceivers_enabled();
        int jna_get_can_transceivers_call_count();
        int jna_get_ir_power_call_count();
        int jna_get_ir_power_value_at(int index);
        void jna_reset_power_save_tracking();

        // CAN comms buffer inspection (comms_can_reset)
        int jna_get_can_read_buffer_ptr();
        int jna_get_can_read_buffer_tail();
        int jna_get_can_write_buffer_ptr();
        int jna_get_can_write_buffer_tail();

        // Version
        String jna_get_gitversion();

        // Packet versions (response from 0xdd)
        void jna_get_packet_versions(int[] outHealthVersion, int[] outCanVersionHash);

        // Hardware type
        int jna_get_hw_type();

        // CAN FD bus_config inspection
        int jna_get_bus_canfd_auto(int bus);
        int jna_get_bus_canfd_non_iso(int bus);
        int jna_get_bus_canfd_enabled(int bus);
        int jna_get_bus_brs_enabled(int bus);
        int jna_get_bus_can_data_speed(int bus);

        // Clock source tracking
        int jna_get_TIM1_CCR1();
        int jna_get_TIM1_CCR2();
        int jna_get_TIM8_CCR3();
        int jna_get_TIM1_ARR();
        int jna_get_TIM1_CCR4();
        void jna_reset_TIM_regs();

        // Microsecond timer and fan RPM
        int jna_get_microsecond_timer();
        int jna_get_fan_rpm();

        // Setup + response buffer
        void jna_set_microsecond_timer(int val);
        void jna_set_fan_rpm(int val);
        int jna_get_resp_len();
        int jna_get_resp_byte(int index);

        // Setup for read-request tests
        void jna_set_hw_type(int val);
        void jna_set_gitversion(String val);
        void jna_set_som_gpio(int val);

        // CAN health inspection
        int jna_get_can_health_speed(int bus);
        int jna_get_can_health_data_speed(int bus);
        int jna_get_can_health_canfd_enabled(int bus);
        int jna_get_can_health_brs_enabled(int bus);
        int jna_get_can_health_canfd_non_iso(int bus);
        int jna_get_can_health_last_error(int bus);
        int jna_get_can_health_receive_error_cnt(int bus);
        int jna_get_can_health_transmit_error_cnt(int bus);
        int jna_get_can_health_can_core_reset_cnt(int bus);
        int jna_get_can_health_bus_off_cnt(int bus);
        int jna_get_can_health_error_warning(int bus);
        int jna_get_can_health_error_passive(int bus);
        int jna_get_can_health_last_data_error(int bus);
        int jna_get_can_health_total_error_cnt(int bus);
        int jna_get_can_health_total_rx_lost_cnt(int bus);
        int jna_get_can_health_irq0_call_rate(int bus);
        int jna_get_can_health_irq1_call_rate(int bus);
        void jna_reset_can_health();
        void jna_call_update_can_health_pkt(int canNumber, int irReg);

        // FDCAN PSR/ECR inspection
        int jna_get_fdcan_psr(int bus);
        int jna_get_fdcan_ecr(int bus);
        void jna_set_fdcan_psr(int bus, int val);
        void jna_set_fdcan_ecr(int bus, int val);
    }

    private final PandaLib lib = PandaLib.INSTANCE;

    public int getSafetyTxBlocked() {
        return lib.jna_get_safety_tx_blocked();
    }

    public AdaptiveList<CanMessage> rxQueue() {
        int[] outAddr = new int[1];
        byte[] outBus = new byte[1];
        byte[] outRejected = new byte[1];
        byte[] outData = new byte[64];
        byte[] outLen = new byte[1];

        var canMessages = new ArrayList<CanMessage>();
        if (lib.jna_can_pop_rx(outAddr, outBus, outRejected, outData, outLen)) {
            int len = Byte.toUnsignedInt(outLen[0]);
            byte[] data = new byte[len];
            System.arraycopy(outData, 0, data, 0, len);
            canMessages.add(new CanMessage(outAddr[0], Byte.toUnsignedInt(outBus[0]), data, outRejected[0] != 0));
        }
        return AdaptiveList.staticList(canMessages);
    }

    public AdaptiveList<CanMessage> txQueue(int bus) {
        int[] outAddr = new int[1];
        byte[] outData = new byte[64];
        byte[] outLen = new byte[1];

        var canMessages = new ArrayList<CanMessage>();
        if (lib.jna_can_pop_tx(bus, outAddr, outData, outLen)) {
            int len = Byte.toUnsignedInt(outLen[0]);
            byte[] data = new byte[len];
            System.arraycopy(outData, 0, data, 0, len);
            canMessages.add(new CanMessage(outAddr[0], bus, data, false));
        }
        return AdaptiveList.staticList(canMessages);
    }

    public void clearCanQueues() {
        lib.jna_can_clear_all();
    }

    public RelayCall relayCall() {
        int count = lib.jna_get_relay_call_count();
        return (count == 0) ? null : new RelayCall(
                lib.jna_get_relay_a() != 0,
                lib.jna_get_relay_b() != 0);
    }

    public void clearRelayCalls() {
        lib.jna_clear_relay_calls();
    }



    public CanModeCall canModeCall() {
        int count = lib.jna_get_can_mode_call_count();
        return (count == 0) ? null : new CanModeCall(lib.jna_get_can_mode());
    }

    public void clearCanModeCalls() {
        lib.jna_clear_can_mode_calls();
    }

    public void controlWrite(byte request, short param1, short param2) {
        lib.jna_control_write(request, param1, param2);
    }

    public int canSend(int address, byte[] data, byte bus) {
        return lib.jna_can_send(address, bus, data, (byte) data.length);
    }

    public void clearAll() {
        clearCanQueues();
        clearRelayCalls();
        clearCanModeCalls();
        lib.jna_reset_fdcan();
        lib.jna_reset_heartbeat();
        lib.jna_reset_safety();
        lib.jna_reset_alternative_experience();
        lib.jna_reset_siren();
        lib.jna_reset_power_save_tracking();
        lib.jna_reset_TIM_regs();
        lib.jna_reset_can_health();
    }

    // ---- FDCAN register inspection ----

    /**
     * One FDCAN peripheral's register state, exposed as byte-list properties.
     * Each list holds register bytes in little-endian order (index 0 = least significant byte).
     * <p>
     * CCCR:   Control — protocol config bits
     * IE:     Interrupt Enable — which events trigger IRQ
     * NBTP:   Nominal Bit Timing & Prescaler
     * DBTP:   Data Bit Timing & Prescaler
     * TXBC:   TX Buffer Configuration
     * RXF0C:  RX FIFO 0 Configuration
     * TXESC:  TX Element Size Configuration (64B CAN FD)
     * RXESC:  RX Element Size Configuration (64B CAN FD)
     * GFC:    Global Filter Configuration (0 = promiscuous mode)
     * ILE:    Interrupt Line Enable (INT0 + INT1)
     */
    public record FdcanRegs(
            List<Byte> cccr,
            List<Byte> ie,
            List<Byte> nbtp,
            List<Byte> dbtp,
            List<Byte> txbc,
            List<Byte> rxf0c,
            List<Byte> txesc,
            List<Byte> rxesc,
            List<Byte> gfc,
            List<Byte> ile,
            List<Byte> ir
    ) {
    }

    private static List<Byte> bytes(int val, int count) {
        var list = new ArrayList<Byte>();
        for (int i = 0; i < count; i++) {
            list.add((byte) ((val >>> (i * 8)) & 0xFF));
        }
        return list;
    }

    /**
     * All 3 FDCAN peripheral register snapshots — one per CAN bus.
     * Use in feature test as:
     * fdcanRegs[0]= { cccr: [...], ie: [...], ... }
     * fdcanRegs[1]= { cccr: [...], ie: [...], ... }
     * fdcanRegs[2]= { cccr: [...], ie: [...], ... }
     */
    public AdaptiveList<FdcanRegs> fdcanRegs() {
        var list = new ArrayList<FdcanRegs>();
        for (int i = 0; i < 3; i++) {
            list.add(new FdcanRegs(
                    bytes(lib.jna_get_fdcan_cccr(i), 2),
                    bytes(lib.jna_get_fdcan_ie(i), 4),
                    bytes(lib.jna_get_fdcan_nbtp(i), 4),
                    bytes(lib.jna_get_fdcan_dbtp(i), 4),
                    bytes(lib.jna_get_fdcan_txbc(i), 4),
                    bytes(lib.jna_get_fdcan_rxf0c(i), 4),
                    bytes(lib.jna_get_fdcan_txesc(i), 1),
                    bytes(lib.jna_get_fdcan_rxesc(i), 1),
                    bytes(lib.jna_get_fdcan_gfc(i), 1),
                    bytes(lib.jna_get_fdcan_ile(i), 1),
                    bytes(lib.jna_get_fdcan_ir(i), 4)
            ));
        }
        return AdaptiveList.staticList(list);
    }

    // ---- Heartbeat state ----
    public record Heartbeat(
            int counter,
            int lost,
            int disabled,
            int engaged
    ) {
    }

    public Heartbeat getHeartbeat() {
        return new Heartbeat(
                lib.jna_get_heartbeat_counter(),
                lib.jna_get_heartbeat_lost(),
                lib.jna_get_heartbeat_disabled(),
                lib.jna_get_heartbeat_engaged()
        );
    }

    public boolean isPowerSaveEnabled() {
        return lib.jna_get_power_save_enabled() != 0;
    }

    public int getAlternativeExperience() {
        return lib.jna_get_alternative_experience();
    }

    public boolean isSirenEnabled() {
        return lib.jna_get_siren_enabled() != 0;
    }

    // ---- Power-save hardware call tracking ----

    public record PowerSaveTracking(
            int irqEnableCount,
            int irqDisableCount,
            int lastIrqEnabledBus,
            boolean irqDisabledBus0,
            boolean irqDisabledBus1,
            boolean irqDisabledBus2,
            boolean canTransceiversEnabled,
            int canTransceiversCallCount,
            int irPowerValue,
            int irPowerCallCount
    ) {
    }

    public PowerSaveTracking getPowerSaveTracking() {
        return new PowerSaveTracking(
                lib.jna_get_irq_enable_call_count(),
                lib.jna_get_irq_disable_call_count(),
                lib.jna_get_last_irq_enabled_bus(),
                lib.jna_get_irq_disabled_bus(0) != 0,
                lib.jna_get_irq_disabled_bus(1) != 0,
                lib.jna_get_irq_disabled_bus(2) != 0,
                lib.jna_get_can_transceivers_enabled() != 0,
                lib.jna_get_can_transceivers_call_count(),
                lib.jna_get_ir_power_value_at(0),
                lib.jna_get_ir_power_call_count()
        );
    }

    // ---- CAN comms buffer state ----

    public record CanCommsBuffers(
            int readBufferPtr,
            int readBufferTail,
            int writeBufferPtr,
            int writeBufferTail
    ) {
    }

    public CanCommsBuffers getCanCommsBuffers() {
        return new CanCommsBuffers(
                lib.jna_get_can_read_buffer_ptr(),
                lib.jna_get_can_read_buffer_tail(),
                lib.jna_get_can_write_buffer_ptr(),
                lib.jna_get_can_write_buffer_tail()
        );
    }

    public String getGitversion() {
        return lib.jna_get_gitversion();
    }

    public record PacketVersions(int healthVersion, int canVersionHash) {
    }

    public PacketVersions getPacketVersions() {
        int[] outHealth = new int[1];
        int[] outCan = new int[1];
        lib.jna_get_packet_versions(outHealth, outCan);
        return new PacketVersions(outHealth[0], outCan[0]);
    }

    public int getHwType() {
        return lib.jna_get_hw_type();
    }

    // ---- CAN FD bus_config ----

    public record CanFdConfig(
            boolean canfdAuto0,
            boolean canfdAuto1,
            boolean canfdAuto2,
            boolean canfdNonIso0,
            boolean canfdNonIso1,
            boolean canfdNonIso2,
            boolean canfdEnabled0,
            boolean canfdEnabled1,
            boolean canfdEnabled2,
            boolean brsEnabled0,
            boolean brsEnabled1,
            boolean brsEnabled2,
            int canDataSpeed0,
            int canDataSpeed1,
            int canDataSpeed2
    ) {
    }

    public CanFdConfig getCanFdConfig() {
        return new CanFdConfig(
                lib.jna_get_bus_canfd_auto(0) != 0,
                lib.jna_get_bus_canfd_auto(1) != 0,
                lib.jna_get_bus_canfd_auto(2) != 0,
                lib.jna_get_bus_canfd_non_iso(0) != 0,
                lib.jna_get_bus_canfd_non_iso(1) != 0,
                lib.jna_get_bus_canfd_non_iso(2) != 0,
                lib.jna_get_bus_canfd_enabled(0) != 0,
                lib.jna_get_bus_canfd_enabled(1) != 0,
                lib.jna_get_bus_canfd_enabled(2) != 0,
                lib.jna_get_bus_brs_enabled(0) != 0,
                lib.jna_get_bus_brs_enabled(1) != 0,
                lib.jna_get_bus_brs_enabled(2) != 0,
                lib.jna_get_bus_can_data_speed(0),
                lib.jna_get_bus_can_data_speed(1),
                lib.jna_get_bus_can_data_speed(2)
        );
    }

    public record ClockSource(int ccr1, int ccr2, int ccr3, int arr, int ccr4) {
    }

    public ClockSource getClockSource() {
        return new ClockSource(
                lib.jna_get_TIM1_CCR1(),
                lib.jna_get_TIM1_CCR2(),
                lib.jna_get_TIM8_CCR3(),
                lib.jna_get_TIM1_ARR(),
                lib.jna_get_TIM1_CCR4()
        );
    }

    public int getMicrosecondTimer() {
        return lib.jna_get_microsecond_timer();
    }

    public int getFanRpm() {
        return lib.jna_get_fan_rpm();
    }

    public void setMicrosecondTimer(int val) {
        lib.jna_set_microsecond_timer(val);
    }

    public void setFanRpm(int val) {
        lib.jna_set_fan_rpm(val);
    }

    public void setHwType(int val) {
        lib.jna_set_hw_type(val);
    }

    public void setGitversion(String val) {
        lib.jna_set_gitversion(val);
    }

    public void setSomGpio(int val) {
        lib.jna_set_som_gpio(val);
    }

    // ---- CAN health inspection ----

    public record CanHealth(
            int canSpeed,
            int canDataSpeed,
            boolean canfdEnabled,
            boolean brsEnabled,
            boolean canfdNonIso,
            int lastError,
            int lastDataError,
            int receiveErrorCnt,
            int transmitErrorCnt,
            int errorWarning,
            int errorPassive,
            int busOffCnt,
            int totalErrorCnt,
            int totalRxLostCnt,
            int canCoreResetCnt,
            int irq0CallRate,
            int irq1CallRate
    ) {
    }

    public CanHealth getCanHealth(int bus) {
        return new CanHealth(
                lib.jna_get_can_health_speed(bus),
                lib.jna_get_can_health_data_speed(bus),
                lib.jna_get_can_health_canfd_enabled(bus) != 0,
                lib.jna_get_can_health_brs_enabled(bus) != 0,
                lib.jna_get_can_health_canfd_non_iso(bus) != 0,
                lib.jna_get_can_health_last_error(bus),
                lib.jna_get_can_health_last_data_error(bus),
                lib.jna_get_can_health_receive_error_cnt(bus),
                lib.jna_get_can_health_transmit_error_cnt(bus),
                lib.jna_get_can_health_error_warning(bus),
                lib.jna_get_can_health_error_passive(bus),
                lib.jna_get_can_health_bus_off_cnt(bus),
                lib.jna_get_can_health_total_error_cnt(bus),
                lib.jna_get_can_health_total_rx_lost_cnt(bus),
                lib.jna_get_can_health_can_core_reset_cnt(bus),
                lib.jna_get_can_health_irq0_call_rate(bus),
                lib.jna_get_can_health_irq1_call_rate(bus)
        );
    }

    public CanHealth getCanHealth0() { return getCanHealth(0); }

    public void callUpdateCanHealthPkt(int canNumber, int irReg) {
        lib.jna_call_update_can_health_pkt(canNumber, irReg);
    }

    public void setFdcanPsr(int bus, int val) { lib.jna_set_fdcan_psr(bus, val); }
    public void setFdcanEcr(int bus, int val) { lib.jna_set_fdcan_ecr(bus, val); }

    public record RespBuffer(AdaptiveList<Byte> bytes, int len) {
    }

    public RespBuffer getRespBuffer() {
        int len = lib.jna_get_resp_len();
        var list = new ArrayList<Byte>();
        for (int i = 0; i < len; i++) {
            list.add((byte) lib.jna_get_resp_byte(i));
        }
        return new RespBuffer(AdaptiveList.staticList(list), len);
    }

    public AdaptiveList<Integer> getIrPower() {
        int count = lib.jna_get_ir_power_call_count();
        var list = new ArrayList<Integer>();
        for (int i = 0; i < count; i++) {
            list.add(lib.jna_get_ir_power_value_at(i));
        }
        return AdaptiveList.staticList(list);
    }

    // ---- Health packet inspection ----

    public record HealthPacket(
            int uptime,
            int voltage,
            int current,
            int safetyTxBlocked,
            int safetyRxInvalid,
            int safetyMode,
            int safetyParam,
            int heartbeatLost
    ) {
    }

    public HealthPacket getHealthPacket() {
        lib.jna_read_health_pkt();
        return new HealthPacket(
                lib.jna_get_health_uptime(),
                lib.jna_get_health_voltage(),
                lib.jna_get_health_current(),
                lib.jna_get_health_safety_tx_blocked(),
                lib.jna_get_health_safety_rx_invalid(),
                lib.jna_get_health_safety_mode(),
                lib.jna_get_health_safety_param(),
                lib.jna_get_health_heartbeat_lost()
        );
    }
}
