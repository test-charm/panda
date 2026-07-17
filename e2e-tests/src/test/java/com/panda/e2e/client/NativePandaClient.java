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
public class NativePandaClient implements PandaClient {

    public interface SafetyLib extends Library {
        SafetyLib INSTANCE = Native.load(
                System.getProperty("user.dir") + "/src/test/c/libpanda.dylib", SafetyLib.class);

        void jna_control_write(byte request, short param1, short param2);
        int  jna_control_read(byte request, short param1, short param2);
        byte jna_get_response_byte(int offset);

        // Legacy direct calls (still used for can_silent)
        void jna_set_safety_mode(short mode, short param);
        byte jna_get_can_silent();
    }

    private final SafetyLib lib = SafetyLib.INSTANCE;
    private final List<CanMessage> rxBuffer = new ArrayList<>();

    @Override public void connect() {}

    @Override
    public void setSafetyMode(int mode, int param) {
        // Full path: comms_control_handler → case 0xdc → set_safety_mode()
        lib.jna_control_write((byte) 0xdc, (short) mode, (short) param);
    }

    @Override
    public void setSafetyModeRaw(int mode, int param) {
        lib.jna_control_write((byte) 0xdc, (short) mode, (short) param);
    }

    @Override public void setCanLoopback(boolean enable) {
        lib.jna_control_write((byte) 0xe5, (short) (enable ? 1 : 0), (short) 0);
    }

    @Override public void canClear(int bus) { rxBuffer.clear(); }

    @Override
    public int getHealthSafetyMode() {
        // Full path: comms_control_handler → case 0xd2 → get_health_pkt()
        lib.jna_control_read((byte) 0xd2, (short) 0, (short) 0);
        return Byte.toUnsignedInt(lib.jna_get_response_byte(36));
    }

    @Override
    public void canSend(int address, byte[] data, int bus) {
        boolean silent = lib.jna_get_can_silent() != 0;
        int resultBus = silent ? bus + 192 : bus;
        rxBuffer.add(new CanMessage(address, resultBus, data));
    }

    @Override
    public List<CanMessage> canRecvParsed(int timeoutMs) {
        if (rxBuffer.isEmpty()) return Collections.emptyList();
        List<CanMessage> result = new ArrayList<>(rxBuffer);
        rxBuffer.clear();
        return result;
    }

    @Override
    public void controlWrite(byte request, short param1, short param2) {
        lib.jna_control_write(request, param1, param2);
    }

    @Override public void close() { rxBuffer.clear(); }
}
