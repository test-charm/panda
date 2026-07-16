package com.panda.e2e.client;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Set;

/**
 * Stub panda client that replicates {@code board/main.c:set_safety_mode()}
 * behavior in pure Java. No hardware required — used for CI.
 *
 * <p>Firmware behavior replicated:
 * <ul>
 *   <li>SILENT(0): can_silent=true, relay off</li>
 *   <li>NOOUTPUT(19): can_silent=false, relay off</li>
 *   <li>ELM327(3): can_silent=false, heartbeat reset</li>
 *   <li>ALLOUTPUT(17): can_silent=false, relay off</li>
 *   <li>Car modes (e.g. TOYOTA=16): relay on, heartbeat reset</li>
 *   <li>Invalid mode: fallback to SILENT(0)</li>
 *   <li>SILENT + loopback: CAN TX appears as rejected (bus+192)</li>
 * </ul>
 */
public class StubPandaClient implements PandaClient {

    /** Known valid safety modes from the firmware. */
    private static final Set<Integer> VALID_MODES =
            Set.of(0 /* SILENT */, 3 /* ELM327 */, 16 /* TOYOTA */, 17 /* ALLOUTPUT */,
                   19 /* NOOUTPUT */, 32 /* HONDA */);

    private int safetyMode = 0;
    private boolean loopback;
    private final List<CanMessage> rxBuffer = new ArrayList<>();

    @Override
    public void connect() {
        // stub: always succeeds
    }

    @Override
    public void setSafetyMode(int mode, int param) {
        setSafetyModeRaw(mode, param);
    }

    @Override
    public void setSafetyModeRaw(int mode, int param) {
        if (VALID_MODES.contains(mode)) {
            this.safetyMode = mode;
        } else {
            // Firmware: set_safety_hooks returns -1 → fallback to SILENT
            this.safetyMode = 0;
        }
    }

    @Override
    public void setCanLoopback(boolean enable) {
        this.loopback = enable;
    }

    @Override
    public void canClear(int bus) {
        rxBuffer.clear();
    }

    @Override
    public int getHealthSafetyMode() {
        return safetyMode;
    }

    @Override
    public void canSend(int address, byte[] data, int bus) {
        // Replicate SILENT mode TX blocking: messages appear as "rejected" (bus+192)
        int resultBus = (safetyMode == 0) ? bus + 192 : bus;
        rxBuffer.add(new CanMessage(address, resultBus, data));
    }

    @Override
    public List<CanMessage> canRecvParsed(int timeoutMs) {
        if (rxBuffer.isEmpty()) {
            return Collections.emptyList();
        }
        List<CanMessage> result = new ArrayList<>(rxBuffer);
        rxBuffer.clear();
        return result;
    }

    @Override
    public void close() {
        rxBuffer.clear();
    }
}
