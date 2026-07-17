package com.panda.e2e.client;

import java.util.List;

/**
 * Abstraction for panda device communication.
 * Two implementations: PandaUsbClient (real hardware via JNA/libusb)
 * and StubPandaClient (simulated firmware for CI without hardware).
 */
public interface PandaClient extends AutoCloseable {

    record CanMessage(int address, int bus, byte[] data) {}

    void connect();
    void setSafetyMode(int mode, int param);
    void setSafetyModeRaw(int mode, int param);
    void setCanLoopback(boolean enable);
    void canClear(int bus);
    int getHealthSafetyMode();
    void canSend(int address, byte[] data, int bus);
    List<CanMessage> canRecvParsed(int timeoutMs);

    void controlWrite(byte request, short param1, short param2);

    @Override
    void close();
}
