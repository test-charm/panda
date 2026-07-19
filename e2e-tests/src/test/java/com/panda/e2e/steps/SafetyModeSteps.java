package com.panda.e2e.steps;

import com.panda.e2e.client.NativePandaClient;
import com.panda.e2e.client.PandaClient;
import com.panda.e2e.client.PandaClient.CanMessage;
import com.panda.e2e.client.PandaUsbClient;
import com.panda.e2e.context.TestContext;
import io.cucumber.java.After;
import io.cucumber.java.Before;
import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;
import org.springframework.beans.factory.annotation.Autowired;
import org.testcharm.jfactory.JFactory;

import java.nio.charset.StandardCharsets;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.testcharm.dal.Assertions.expect;

public class SafetyModeSteps {

    private final TestContext ctx = new TestContext();
    private static final PandaClient CLIENT = createClient();

    static {
        if (CLIENT instanceof NativePandaClient) {
            System.out.println("[native] Using firmware from board/main.c via JNA");
        }
    }

    private static PandaClient createClient() {
        PandaUsbClient real = null;
        try {
            real = new PandaUsbClient();
            real.connect();
            return real;
        } catch (RuntimeException e) {
            if (real != null) real.close();
            return new NativePandaClient(); // real C code, no hardware
        }
    }

    @Before
    public void setUp() {
        // Reset to known state before each scenario
        CLIENT.setSafetyMode(0, 0);
        CLIENT.setCanLoopback(false);
        CLIENT.canClear(0xFFFF);
        CLIENT.canClear(0);
        CLIENT.canClear(1);
        CLIENT.canClear(2);
        // Also clear C-side CAN queues for pipeline tests
        if (CLIENT instanceof NativePandaClient nc) {
            nc.clearAllCanQueues();
        }
        ctx.setClient(CLIENT);
    }

    @After
    public void tearDown() {
        if (ctx.getClient() != null) {
            ctx.getClient().close();
        }
    }

    // ---- When: safety mode ----

    @When("I set safety mode to {string}")
    public void setSafetyMode(String modeName) {
        int mode = resolveSafetyMode(modeName);
        ctx.getClient().setSafetyMode(mode, 0);
    }

    @When("I set safety mode to {string} with param {int}")
    public void setSafetyModeWithParam(String modeName, int param) {
        int mode = resolveSafetyMode(modeName);
        ctx.getClient().setSafetyMode(mode, param);
    }

    @When("I set an invalid safety mode {int}")
    public void setInvalidSafetyMode(int mode) {
        ctx.getClient().setSafetyModeRaw(mode, 0);
    }

    // ---- When: CAN operations ----

    @When("I enable CAN loopback")
    public void enableCanLoopback() {
        ctx.getClient().setCanLoopback(true);
    }

    @When("I send a CAN message with address {int} and data {string} on bus {int}")
    public void sendCanMessage(int address, String data, int bus) {
        byte[] bytes = data.getBytes(StandardCharsets.UTF_8);
        ctx.getClient().canSend(address, bytes, bus);
    }

    @When("I wait {int} milliseconds")
    public void waitMilliseconds(int ms) {
        try {
            Thread.sleep(ms);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }

    @When("I receive CAN messages")
    public void receiveCanMessages() {
        List<CanMessage> msgs = ctx.getClient().canRecvParsed(200);
        ctx.setReceivedMessages(msgs);
    }

    // ---- Then: health assertions ----

    @Then("the safety_mode in health should be {int}")
    public void safetyModeInHealthShouldBe(int expectedMode) {
        int actualMode = ctx.getClient().getHealthSafetyMode();
        assertThat(actualMode).as("health.safety_mode").isEqualTo(expectedMode);
    }

    // ---- Then: CAN assertions ----

    @Then("no CAN message should appear on bus {int}")
    public void noCanMessageOnBus(int bus) {
        long count = ctx.getReceivedMessages().stream().filter(m -> m.bus() == bus).count();
        assertThat(count).as("messages on bus %d", bus).isZero();
    }

    @Then("exactly {int} CAN message should appear on bus {int}")
    public void exactlyNMessagesOnBus(int expected, int bus) {
        long count = ctx.getReceivedMessages().stream().filter(m -> m.bus() == bus).count();
        assertThat(count).as("messages on bus %d", bus).isEqualTo(expected);
    }

    // ---- When: CAN pipeline (real can_send → safety_tx_hook → can_push) ----

    @When("I send CAN through safety pipeline with address {int} and data {string} on bus {int}")
    public void sendCanThroughSafetyPipeline(int address, String data, int bus) {
        if (!(ctx.getClient() instanceof NativePandaClient nc)) {
            throw new UnsupportedOperationException("Pipeline tests require NativePandaClient");
        }
        byte[] bytes = data.getBytes(StandardCharsets.UTF_8);
        // Record baseline counter before send
        ctx.setSafetyTxBlockedBefore(nc.getSafetyTxBlocked());
        int result = nc.canSendPipeline(address, bytes, bus);
        ctx.setPipelineResult(result);
    }

    // ---- Then: CAN pipeline assertions ----

    @Then("the CAN pipeline message should be blocked")
    public void canPipelineMessageShouldBeBlocked() {
        assertThat(ctx.getPipelineResult()).as("can_send pipeline result").isEqualTo(1);
    }

    @Then("the CAN pipeline message should be allowed")
    public void canPipelineMessageShouldBeAllowed() {
        assertThat(ctx.getPipelineResult()).as("can_send pipeline result").isEqualTo(0);
    }

    @Then("safety_tx_blocked counter should increase by 1")
    public void safetyTxBlockedCounterShouldIncrease() {
        if (!(ctx.getClient() instanceof NativePandaClient nc)) {
            throw new UnsupportedOperationException("Pipeline tests require NativePandaClient");
        }
        int after = nc.getSafetyTxBlocked();
        assertThat(after - ctx.getSafetyTxBlockedBefore())
                .as("safety_tx_blocked delta").isEqualTo(1);
    }

    @Then("the rejected CAN message should appear in rx queue with address {int} and bus {int}")
    public void rejectedMessageInRxQueue(int expectedAddr, int expectedBus) {
        if (!(ctx.getClient() instanceof NativePandaClient nc)) {
            throw new UnsupportedOperationException("Pipeline tests require NativePandaClient");
        }
        CanMessage msg = nc.popRxQueue();
        assertThat(msg).as("rx queue message").isNotNull();
        assertThat(msg.address()).as("rx message address").isEqualTo(expectedAddr);
        assertThat(msg.bus()).as("rx message bus").isEqualTo(expectedBus);
    }

    @Then("the tx queue for bus {int} should be empty")
    public void txQueueShouldBeEmpty(int bus) {
        if (!(ctx.getClient() instanceof NativePandaClient nc)) {
            throw new UnsupportedOperationException("Pipeline tests require NativePandaClient");
        }
        CanMessage msg = nc.popTxQueue(bus);
        assertThat(msg).as("tx queue message for bus %d", bus).isNull();
    }

    @Then("the tx queue for bus {int} should contain a message with address {int}")
    public void txQueueShouldContainMessage(int bus, int expectedAddr) {
        if (!(ctx.getClient() instanceof NativePandaClient nc)) {
            throw new UnsupportedOperationException("Pipeline tests require NativePandaClient");
        }
        CanMessage msg = nc.popTxQueue(bus);
        assertThat(msg).as("tx queue message for bus %d", bus).isNotNull();
        assertThat(msg.address()).as("tx message address").isEqualTo(expectedAddr);
    }

    @Then("the rx queue should be empty")
    public void rxQueueShouldBeEmpty() {
        if (!(ctx.getClient() instanceof NativePandaClient nc)) {
            throw new UnsupportedOperationException("Pipeline tests require NativePandaClient");
        }
        CanMessage msg = nc.popRxQueue();
        assertThat(msg).as("rx queue message").isNull();
    }

    // ---- Helpers ----

    private static int resolveSafetyMode(String modeName) {
        return switch (modeName.toUpperCase()) {
            case "SILENT" -> 0;
            case "NOOUTPUT" -> 19;
            case "ELM327" -> 3;
            case "ALLOUTPUT" -> 17;
            case "TOYOTA" -> 16;
            case "HONDA" -> 32;
            default -> throw new IllegalArgumentException("Unknown safety mode: " + modeName);
        };
    }

    @Autowired
    private JFactory jFactory;

    @When("control write:")
    public void controlWriteWithExpression(String expression) {
        var request = jFactory.useDAL().create(UsbControlRequest.class, expression);
        ctx.getClient().controlWrite(request.request, request.param1, request.param2);
    }

    @When("control write {string}:")
    public void controlWriteWithSpec(String spec, String expression) {
        UsbControlRequest request = jFactory.useDAL().create(spec, expression);
        ctx.getClient().controlWrite(request.request, request.param1, request.param2);
    }

    @Then("control read {string} should:")
    public void controlReadShould(String requestExp, String verifyExp) {
        var request = jFactory.useDAL().create(UsbControlRequest.class, requestExp);
        ctx.getClient().controlRead(request.request, request.param1, request.param2);
        expect(ctx.getClient()).should(verifyExp);
    }

    public static class UsbControlRequest {
        public byte request;
        public short param1, param2;
    }
}
