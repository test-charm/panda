package com.panda.e2e.client;

import com.sun.jna.Library;
import com.sun.jna.Native;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Panda client backed by REAL firmware code from board/main.c compiled as .dylib.
 * Calls set_safety_mode() via JNA. Used for mutation testing without hardware.
 */
public class NativePandaClient implements PandaClient {

    private static final String LIB_PATH;

    static {
        // Resolve dylib relative to project or via classpath
        String cwd = System.getProperty("user.dir");
        LIB_PATH = cwd + "/src/test/c/libpanda_safety.dylib";
    }

    public interface SafetyLib extends Library {
        SafetyLib INSTANCE = Native.load(LIB_PATH, SafetyLib.class);
        void jna_set_safety_mode(short mode, short param);
        byte jna_get_can_silent();
    }

    private final SafetyLib lib = SafetyLib.INSTANCE;
    private int lastSetMode;
    private final List<CanMessage> rxBuffer = new ArrayList<>();

    @Override
    public void connect() {}

    @Override
    public void setSafetyMode(int mode, int param) {
        lib.jna_set_safety_mode((short) mode, (short) param);
        lastSetMode = (lib.jna_get_can_silent() != 0) ? 0 : mode;
    }

    @Override
    public void setSafetyModeRaw(int mode, int param) {
        lib.jna_set_safety_mode((short) mode, (short) param);
        lastSetMode = (lib.jna_get_can_silent() != 0) ? 0 : mode;
    }

    @Override
    public void setCanLoopback(boolean enable) {}

    @Override
    public void canClear(int bus) { rxBuffer.clear(); }

    @Override
    public int getHealthSafetyMode() { return lastSetMode; }

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
    public void close() { rxBuffer.clear(); }
}
