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
