package com.panda.e2e.steps;

import com.panda.e2e.client.NativePandaClient;
import com.panda.e2e.client.PandaClient;
import com.panda.e2e.client.PandaClient.CanMessage;
import com.panda.e2e.client.PandaUsbClient;
import com.panda.e2e.context.TestContext;
import io.cucumber.java.After;
import io.cucumber.java.Before;
import io.cucumber.java.en.Given;
import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;

import java.nio.charset.StandardCharsets;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

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
        ctx.setClient(CLIENT);
    }

    @After
    public void tearDown() {
        if (ctx.getClient() != null) {
            ctx.getClient().close();
        }
    }

    // ---- Given ----

    @Given("the panda is connected")
    public void pandaIsConnected() {
        // Client already initialized in @Before
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
}
