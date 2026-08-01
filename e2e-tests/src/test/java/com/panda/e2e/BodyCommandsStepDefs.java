package com.panda.e2e;

import com.panda.e2e.spec.BodyUsbControlRequests;
import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;
import org.springframework.beans.factory.annotation.Autowired;
import org.testcharm.jfactory.JFactory;
import org.testcharm.util.Classes;

import static org.testcharm.dal.Assertions.expect;

public class BodyCommandsStepDefs {

    @Autowired
    private BodyPandaClient bodyClient;

    @When("body control write:")
    public void bodyControlWrite(String expression) {
        var jFactory = newJFactory(BodyUsbControlRequests.BodyUsbControlRequest.class);
        jFactory.useDAL().createAll(expression);
        var request = jFactory.type(BodyPandaClient.BodyControlRequest.class).query();
        bodyClient.controlWrite(request.request, request.param1, request.param2);
    }

    @When("bldc init")
    public void bldcInit() {
        bodyClient.bldcInit();
    }

    @Then("body control data should be:")
    public void bodyControlDataShould(String expression) {
        expect(bodyClient).should(expression);
    }

    private JFactory newJFactory(Class<?> specSuperClass) {
        var jFactory = new JFactory();
        Classes.assignableTypesOf(specSuperClass, "com.panda.e2e.spec")
                .forEach(spec -> jFactory.register((Class) spec));
        return jFactory;
    }
}
