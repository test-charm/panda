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

public class SafetyModeSteps {

    @Autowired
    private PandaClient client;

    @When("control write:")
    public void controlWriteWithExpression(String expression) {
        var jFactory = createJFactoryWithSpec(UsbControlRequests.UsbControlRequest.class);
        jFactory.useDAL().createAll(expression);
        var request = jFactory.type(UsbControlRequest.class).query();
        client.controlWrite(request.request, request.param1, request.param2);
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

    @Then("control data should be:")
    public void controlDataShould(String expression) {
        expect(client).should(expression);
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

    public static class ControlSetup {
        public int timerValue;
        public int fanRpm;
        public int hwType;
        public String gitversion;
    }
}
