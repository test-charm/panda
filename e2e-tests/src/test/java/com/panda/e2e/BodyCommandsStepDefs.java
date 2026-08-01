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

    @When("bldc skip calibration")
    public void bldcSkipCalibration() {
        bodyClient.bldcSkipCalibration();
    }

    @When("bldc step")
    public void bldcStep() {
        bodyClient.bldcStep();
    }

    @When("set motor speeds: left = {int} rpm, right = {int} rpm, enable = {word}")
    public void setMotorSpeeds(int leftRpm, int rightRpm, String enable) {
        bodyClient.setMotorSpeeds(leftRpm, rightRpm, "true".equals(enable));
    }

    @When("dotstar show")
    public void dotstarShow() { bodyClient.dotstarShow(); }

    @When("dotstar fill: r = {int}, g = {int}, b = {int}")
    public void dotstarFill(int r, int g, int b) { bodyClient.dotstarFill(r, g, b); }

    @When("dotstar set pixel: index = {int}, r = {int}, g = {int}, b = {int}")
    public void dotstarSetPixel(int index, int r, int g, int b) { bodyClient.dotstarSetPixel(index, r, g, b); }

    @When("dotstar set global brightness: {int}")
    public void dotstarSetGlobalBrightness(int brightness) { bodyClient.dotstarSetGlobalBrightness(brightness); }

    @When("dotstar run rainbow: now_us = {int}")
    public void dotstarRunRainbow(int nowUs) { bodyClient.dotstarRunRainbow(nowUs); }

    @When("dotstar apply breathe: r = {int}, g = {int}, b = {int}, now_us = {int}, cycle_us = {int}")
    public void dotstarApplyBreathe(int r, int g, int b, int nowUs, int cycleUs) {
        bodyClient.dotstarApplyBreathe(r, g, b, nowUs, cycleUs);
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
