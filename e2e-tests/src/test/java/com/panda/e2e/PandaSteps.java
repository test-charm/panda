package com.panda.e2e;

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

    @Then("control data should be:")
    public void controlDataShould(String expression) {
        expect(client).should(expression);
    }

    @When("tick handler")
    public void callTickHandler() {
        client.callTickHandler();
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

    @When("comms can write with hex:")
    public void commsCanWrite(String hexExpression) {
        client.commsCanWrite(hexToBytes(hexExpression));
    }

    @When("comms can read with max len {int}")
    public void commsCanRead(int maxLen) {
        client.commsCanRead(maxLen);
    }

    private static byte[] hexToBytes(String hex) {
        String cleaned = hex.replaceAll("\\s+", "");
        byte[] bytes = new byte[cleaned.length() / 2];
        for (int i = 0; i < bytes.length; i++) {
            bytes[i] = (byte) Integer.parseInt(cleaned.substring(i * 2, i * 2 + 2), 16);
        }
        return bytes;
    }

    @When("check can checksum with hex:")
    public void checkCanChecksum(String hexExpression) {
        client.checkCanChecksum(hexToBytes(hexExpression));
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
