package com.panda.e2e;

import com.panda.e2e.spec.CanRxSendRequests;
import com.panda.e2e.spec.CanSendRequests;
import com.panda.e2e.spec.UsbControlRequests;
import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.lang.NonNull;
import org.testcharm.jfactory.JFactory;
import org.testcharm.jfactory.Spec;
import org.testcharm.util.Classes;

import java.nio.charset.StandardCharsets;

import static org.testcharm.dal.Assertions.expect;

public class PandaSteps {

    @Autowired
    private PandaClient client;

    @When("control write:")
    public void controlWriteWithExpression(String expression) {
        var jFactory = createJFactoryWithSpec(UsbControlRequests.UsbControlRequest.class);
        jFactory.useDAL().createAll(expression);
        var request = jFactory.type(UsbControlRequest.class).query();
        client.controlWrite(request.request, request.param1, request.param2, request.length);
    }

    @When("can send with result {int}:")
    public void canSend(int result, String expression) {
        var jFactory = createJFactoryWithSpec(CanSendRequests.CanSendRequest.class);
        jFactory.useDAL().createAll(expression);
        var request = jFactory.type(CanSendRequest.class).query();
        expect(client.canSend(request.address, request.data.getBytes(StandardCharsets.UTF_8), request.bus)).should("= " + result);
    }

    @NonNull
    private JFactory createJFactoryWithSpec(Class<? extends Spec> specSuperClass) {
        var jFactory = new JFactory();
        Classes.assignableTypesOf(specSuperClass, "com.panda.e2e.spec")
                .forEach(spec -> jFactory.register((Class) spec));
        return jFactory;
    }

    @When("process stop mode")
    public void processStopMode() {
        client.processStopMode();
    }

    @When("process wfi idle")
    public void processWfiIdle() {
        client.processWfiIdle();
    }

    @When("tick siren")
    public void tickSiren() {
        client.tickSiren();
    }

    @When("trigger fault {int}")
    public void triggerFault(int fault) {
        client.triggerFault(fault);
    }

    @When("recover fault {int}")
    public void recoverFault(int fault) {
        client.recoverFault(fault);
    }

    @Then("control data should be:")
    public void controlDataShould(String expression) {
        expect(client).should(expression);
    }

    @When("tick handler")
    public void callTickHandler() {
        client.callTickHandler();
    }

    @Then("FDCAN interrupt handlers:")
    public void fdcanInterruptHandlers(String expression) {
        expect(client).should(expression);
    }

    @When("can rx send:")
    public void canRxSend(String expression) {
        var jFactory = createJFactoryWithSpec(CanRxSendRequests.CanRxSendRequest.class);
        jFactory.useDAL().createAll(expression);
        var request = jFactory.type(CanRxSendRequest.class).query();
        int val = ((request.f0gi & 0x3F) << 16) | (request.full << 8) | (request.f0fl & 0x7F);
        client.setFdcanRxf0s(request.rxf0sBus, val);
        client.setFdcanIr(request.irBus, request.rf0n != 0 ? 1 : 0);
        client.canRx(request.canNumber);
    }

    public static class CanRxSendRequest {
        public int rxf0sBus, f0gi, f0fl, full, irBus, rf0n, canNumber;
    }

    public static class UsbControlRequest {
        public byte request;
        public short param1, param2;
        public short length;
    }

    public static class CanSendRequest {
        public int address;
        public String data;
        public byte bus;
    }

    @When("call tick handler {int} times")
    public void callTickHandlerTimes(int times) {
        for (var i = 0; i < times; i++) {
            client.callTickHandler();
        }
    }

    @When("detect harness orientation")
    public void detectHarnessOrientation() {
        client.detectHarnessOrientation();
    }

    @When("USB ep3 out with hex:")
    public void usbEp3Out(String hexExpression) {
        client.usbEp3Out(hexToBytes(hexExpression));
    }

    @When("USB ep1 in with max len {int}")
    public void usbEp1In(int maxLen) {
        client.usbEp1In(maxLen);
    }

    private static byte[] hexToBytes(String hex) {
        String cleaned = hex.replaceAll("\\s+", "");
        byte[] bytes = new byte[cleaned.length() / 2];
        for (int i = 0; i < bytes.length; i++) {
            bytes[i] = (byte) Integer.parseInt(cleaned.substring(i * 2, i * 2 + 2), 16);
        }
        return bytes;
    }

    @When("endpoint2 write with hex:")
    public void endpoint2Write(String hexExpression) {
        client.endpoint2Write(hexToBytes(hexExpression));
    }

    @When("SPI version packet")
    public void spiVersionPacket() {
        client.spiVersionPacket();
    }

    @When("clock source init with channel1 enabled")
    public void clockSourceInitEnabled() {
        client.clockSourceInit(true);
    }

    @When("clock source init with channel1 disabled")
    public void clockSourceInitDisabled() {
        client.clockSourceInit(false);
    }

    @When("board init")
    public void boardInit() {
        client.boardInit();
    }

    @When("set fan enabled through board {int}")
    public void setFanEnabledThroughBoard(int en) {
        client.boardSetFanEnabled(en != 0);
    }

    @When("can push direct to queue {int}")
    public void canPushDirect(int queueIdx) {
        client.canPushDirectAndStore(queueIdx, 0x100, "any".getBytes(StandardCharsets.UTF_8), (byte) 0);
        client.refreshQueueState(queueIdx);
    }

    @When("refresh can slots empty for queue {int}")
    public void refreshCanSlotsEmpty(int queueIdx) {
        client.refreshCanSlotsEmpty(queueIdx);
    }

    @When("can pop direct from queue {int}")
    public void canPopDirect(int queueIdx) {
        client.canPopDirect(queueIdx);
        client.refreshQueueState(queueIdx);
    }

    @When("process can {int}")
    public void processCan(int canNumber) {
        client.processCan(canNumber);
    }

    @When("can rx {int}")
    public void canRx(int canNumber) {
        client.canRx(canNumber);
    }

    // ---- can_rx() RX FIFO injection steps ----

    public static class CanRxInjectRequest {
        public int address;
        public String data;
        public int bus;
        public boolean extended;
        public boolean canfdFrame;
        public boolean brsFrame;
        public int dataLenCode;
        public int elementIndex;
    }

    @When("set fdcan ir bus {int} errors ped {int} pea {int} ep {int} bo {int} rf0l {int}")
    public void setFdcanIrErrors(int bus, int ped, int pea, int ep, int bo, int rf0l) {
        int val = 0;
        if (ped != 0) val |= (1 << 8);
        if (pea != 0) val |= (1 << 9);
        if (ep != 0) val |= (1 << 6);
        if (bo != 0) val |= (1 << 7);
        if (rf0l != 0) val |= (1 << 4);
        client.setFdcanIr(bus, val);
    }

    @When("set forwarding bus {int} to bus {int}")
    public void setForwardingBus(int bus, int fwdBus) {
        client.setBusForwardingBus(bus, fwdBus);
    }

    public static class ControlSetup {
        public int timerValue;
        public int fanRpm;
        public int hwType;
        public String gitversion;
        public int somGpio;
        public int fdcanPsr;
        public int fdcanEcr;
        public int irReg;
        public int voltageMV;
        public int currentMA;
        public int safetyMode;
        public int alternativeExperience;
        public int heartbeatDisabled;
        public long heartbeatCounter;
        public long safetyModeCnt;
        public String mcuUidBytes;
        public int interruptIndex;
        public int interruptCallRate;
        public String serialBytes;
        public String provisionBytes;
        public int codeLen;
        public String signatureChunk0;
        public String signatureChunk1;
        public String uartData;
        public int relayMalfunctionVal;
        public int harnessStatus;
        public int sbu1VoltageMV;
        public int sbu2VoltageMV;
        public int relayDriven;
        public int somUartWptr;
        public int ignitionLine;
        public int ignitionCan;
        public int controlsAllowed;
        public int registerDivergent;
    }
}
