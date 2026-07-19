package com.panda.e2e;

import com.sun.jna.Library;
import com.sun.jna.Native;
import org.springframework.stereotype.Component;
import org.testcharm.dal.runtime.AdaptiveList;

import java.util.ArrayList;

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

    public record CanClearSendCall(int x, int y) {
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

    public CanClearSendCall canClearSendCall() {
        int count = lib.jna_get_can_clear_send_count();
        return (count == 0) ? null : new CanClearSendCall(
                lib.jna_get_can_clear_send_x(),
                lib.jna_get_can_clear_send_y());
    }

    public void clearCanClearSendCalls() {
        lib.jna_clear_can_clear_send_calls();
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
        clearCanClearSendCalls();
    }
}
