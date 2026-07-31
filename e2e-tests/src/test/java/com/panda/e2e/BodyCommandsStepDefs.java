package com.panda.e2e;

import io.cucumber.java.en.And;
import io.cucumber.java.en.Given;
import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;
import org.springframework.beans.factory.annotation.Autowired;

import static org.assertj.core.api.Assertions.assertThat;

public class BodyCommandsStepDefs {

    @Autowired
    private BodyPandaClient bodyPandaClient;

    @Given("the body firmware is initialized")
    public void theBodyFirmwareIsInitialized() {
        // Initialize body firmware state (sets hw_type, etc.)
        bodyPandaClient.init();
    }

    @Given("the motors are enabled")
    public void theMotorsAreEnabled() {
        bodyPandaClient.setMotorEnable(true);
    }

    @When("I set left motor speed to {int} rpm and right motor speed to {int} rpm")
    public void iSetMotorSpeed(int leftRpm, int rightRpm) {
        bodyPandaClient.setMotorSpeed(leftRpm, rightRpm);
    }

    @When("I enable the motors")
    public void iEnableTheMotors() {
        bodyPandaClient.setMotorEnable(true);
    }

    @When("I disable the motors")
    public void iDisableTheMotors() {
        bodyPandaClient.setMotorEnable(false);
    }

    @And("the left motor speed is set to {int} rpm and right motor speed is set to {int} rpm")
    public void theMotorSpeedIsSetTo(int leftRpm, int rightRpm) {
        bodyPandaClient.setMotorSpeed(leftRpm, rightRpm);
    }

    @Then("the left motor target rpm should be {int}")
    public void theLeftMotorTargetRpmShouldBe(int expected) {
        assertThat(bodyPandaClient.getRpmLeft()).isEqualTo(expected);
    }

    @Then("the right motor target rpm should be {int}")
    public void theRightMotorTargetRpmShouldBe(int expected) {
        assertThat(bodyPandaClient.getRpmRight()).isEqualTo(expected);
    }

    @Then("the motors should be disabled")
    public void theMotorsShouldBeDisabled() {
        assertThat(bodyPandaClient.isMotorEnabled()).isFalse();
    }

    @Then("the motors should be enabled")
    public void theMotorsShouldBeEnabled() {
        assertThat(bodyPandaClient.isMotorEnabled()).isTrue();
    }

    // ---- Shared commands (0xc1, 0xd6, 0xdd) ----

    private byte[] lastBodyResponse;

    @When("I send control command {int} to body")
    public void iSendControlCommandToBody(int command) {
        lastBodyResponse = bodyPandaClient.controlWriteWithResponse(command, 0, 0);
    }

    @Then("the response length should be {int}")
    public void theResponseLengthShouldBe(int expected) {
        assertThat(lastBodyResponse).hasSize(expected);
    }

    @And("response byte {int} should be {int}")
    public void responseByteShouldBe(int index, int expected) {
        assertThat(Byte.toUnsignedInt(lastBodyResponse[index])).isEqualTo(expected);
    }

    @Then("the response should be a non-empty string")
    public void theResponseShouldBeANonEmptyString() {
        String s = new String(lastBodyResponse, 0, lastBodyResponse.length);
        // gitversion is null-terminated
        String version = s.replace("\0", "").trim();
        assertThat(version).isNotEmpty();
    }

    @And("the health packet version hash should be {long}")
    public void theHealthPacketVersionHashShouldBe(long expected) {
        long[] hashes = bodyPandaClient.getVersionHashes();
        assertThat(hashes[0]).isEqualTo(expected);
    }

    @And("the CAN packet version hash should be {long}")
    public void theCanPacketVersionHashShouldBe(long expected) {
        long[] hashes = bodyPandaClient.getVersionHashes();
        assertThat(hashes[1]).isEqualTo(expected);
    }
}
