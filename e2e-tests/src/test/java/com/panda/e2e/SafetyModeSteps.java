package com.panda.e2e;

import io.cucumber.java.Before;
import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;
import org.springframework.beans.factory.annotation.Autowired;
import org.testcharm.jfactory.JFactory;

import java.nio.charset.StandardCharsets;

import static org.testcharm.dal.Assertions.expect;

public class SafetyModeSteps {

    @Autowired
    private PandaClient client;

    @Autowired
    private JFactory jFactory;

    @Before
    public void setUp() {
        client.clearCanQueues();
        client.clearRelayCalls();
    }

    @When("control write:")
    public void controlWriteWithExpression(String expression) {
        jFactory.useDAL().createAll(expression);
        var request = jFactory.type(UsbControlRequest.class).query();
        client.controlWrite(request.request, request.param1, request.param2);
    }

    @When("can send with result {int}:")
    public void canSend(int result, String expression) {
        jFactory.useDAL().createAll(expression);
        var request = jFactory.type(CanSendRequest.class).query();
        expect(client.canSend(request.address, request.data.getBytes(StandardCharsets.UTF_8), request.bus)).should("= " + result);
    }

    @Then("control data should be:")
    public void controlDataShould(String expression) {
        expect(client).should(expression);
    }

    @When("can send {string} with result {int}:")
    public void canSendWithResult(String spec, int result, String expression) {
        CanSendRequest request = jFactory.useDAL().create(spec, expression);
        expect(client.canSend(request.address, request.data.getBytes(StandardCharsets.UTF_8), request.bus)).should("= " + result);
    }

    public static class UsbControlRequest {
        public byte request;
        public short param1, param2;
    }

    public static class CanSendRequest {
        public int address;
        public String data;
        public byte bus;
    }
}
