package com.panda.e2e.client;

import com.sun.jna.Library;
import com.sun.jna.Native;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Panda client backed by REAL firmware code from board/main.c compiled as .dylib.
 * Goes through the FULL firmware path: comms_control_handler() → set_safety_mode().
 * Used for mutation testing without hardware.
 */
public class PandaClient implements AutoCloseable {

    public record CanMessage(int address, int bus, byte[] data, boolean rejected) {}

    public interface SafetyLib extends Library {
        SafetyLib INSTANCE = Native.load(
                System.getProperty("user.dir") + "/src/test/c/libpanda.dylib", SafetyLib.class);

        void jna_control_write(byte request, short param1, short param2);
        int  jna_control_read(byte request, short param1, short param2);
        byte jna_get_response_byte(int offset);

        // Legacy direct calls (still used for can_silent)
        void jna_set_safety_mode(short mode, short param);
        byte jna_get_can_silent();

        // CAN pipeline testing: real can_send → safety_tx_hook → can_push
        int jna_can_send(int addr, byte bus, byte[] data, byte len);
        int jna_get_safety_tx_blocked();
        boolean jna_can_pop_rx(int[] outAddr, byte[] outBus, byte[] outRejected, byte[] outData, byte[] outLen);
        boolean jna_can_pop_tx(int queueIdx, int[] outAddr, byte[] outData, byte[] outLen);
        void jna_can_clear_all();
    }

    private final SafetyLib lib = SafetyLib.INSTANCE;
    private final List<CanMessage> rxBuffer = new ArrayList<>();

    public void connect() {}

    public void setSafetyMode(int mode, int param) {
        // Full path: comms_control_handler → case 0xdc → set_safety_mode()
        lib.jna_control_write((byte) 0xdc, (short) mode, (short) param);
    }

    public void setSafetyModeRaw(int mode, int param) {
        lib.jna_control_write((byte) 0xdc, (short) mode, (short) param);
    }

    public void setCanLoopback(boolean enable) {
        lib.jna_control_write((byte) 0xe5, (short) (enable ? 1 : 0), (short) 0);
    }

    public void canClear(int bus) { rxBuffer.clear(); }

    public int getHealthSafetyMode() {
        // Full path: comms_control_handler → case 0xd2 → get_health_pkt()
        lib.jna_control_read((byte) 0xd2, (short) 0, (short) 0);
        return Byte.toUnsignedInt(lib.jna_get_response_byte(36));
    }

    public void canSend(int address, byte[] data, int bus) {
        boolean silent = lib.jna_get_can_silent() != 0;
        int resultBus = silent ? bus + 192 : bus;
        rxBuffer.add(new CanMessage(address, resultBus, data, false));
    }

    public List<CanMessage> canRecvParsed(int timeoutMs) {
        if (rxBuffer.isEmpty()) return Collections.emptyList();
        List<CanMessage> result = new ArrayList<>(rxBuffer);
        rxBuffer.clear();
        return result;
    }

    // ---- CAN pipeline testing: real can_send → safety_tx_hook → can_push ----

    /**
     * Send CAN through the real firmware pipeline (can_send → safety_tx_hook → can_push).
     * @return 0 = allowed (queued to can_tx*_q), 1 = blocked (queued to can_rx_q with rejected=1)
     */
    public int canSendPipeline(int address, byte[] data, int bus) {
        return lib.jna_can_send(address, (byte) bus, data, (byte) data.length);
    }

    /** Get the safety_tx_blocked counter (cumulative blocked TX message count). */
    public int getSafetyTxBlocked() {
        return lib.jna_get_safety_tx_blocked();
    }

    /**
     * Pop a message from can_rx_q (blocked/rejected messages end up here).
     * @return CanMessage from the RX queue, or null if queue is empty.
     */
    public CanMessage popRxQueue() {
        int[] outAddr = new int[1];
        byte[] outBus = new byte[1];
        byte[] outRejected = new byte[1];
        byte[] outData = new byte[64];
        byte[] outLen = new byte[1];

        if (lib.jna_can_pop_rx(outAddr, outBus, outRejected, outData, outLen)) {
            int len = Byte.toUnsignedInt(outLen[0]);
            byte[] data = new byte[len];
            System.arraycopy(outData, 0, data, 0, len);
            return new CanMessage(outAddr[0], Byte.toUnsignedInt(outBus[0]), data, outRejected[0] != 0);
        }
        return null;
    }

    /**
     * Pop a message from can_tx{1,2,3}_q (allowed messages end up here).
     * @param bus 0=tx1_q, 1=tx2_q, 2=tx3_q
     * @return CanMessage from the TX queue, or null if queue is empty.
     */
    public CanMessage popTxQueue(int bus) {
        int[] outAddr = new int[1];
        byte[] outData = new byte[64];
        byte[] outLen = new byte[1];

        if (lib.jna_can_pop_tx(bus, outAddr, outData, outLen)) {
            int len = Byte.toUnsignedInt(outLen[0]);
            byte[] data = new byte[len];
            System.arraycopy(outData, 0, data, 0, len);
            return new CanMessage(outAddr[0], bus, data, false);
        }
        return null;
    }

    /** Clear all CAN ring buffer queues (rx_q, tx1_q, tx2_q, tx3_q). */
    public void clearAllCanQueues() {
        lib.jna_can_clear_all();
    }

    public void controlWrite(byte request, short param1, short param2) {
        lib.jna_control_write(request, param1, param2);
    }

    public void controlRead(byte request, short param1, short param2) {
        lib.jna_control_read(request, param1, param2);
    }

    public byte getResponseByte(int offset) {
        return lib.jna_get_response_byte(offset);
    }

    public int canSendNew(int address, byte[] data, byte bus) {
        return lib.jna_can_send(address, (byte) bus, data, (byte) data.length);
    }

    @Override public void close() { rxBuffer.clear(); }
}
