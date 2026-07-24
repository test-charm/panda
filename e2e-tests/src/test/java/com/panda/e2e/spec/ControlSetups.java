package com.panda.e2e.spec;

import com.panda.e2e.SafetyModeSteps;
import org.testcharm.jfactory.Spec;

public class ControlSetups {

    public static class ControlSetup extends Spec<SafetyModeSteps.ControlSetup> {
        @Override
        public void main() {
            property("timerValue").defaultValue(0);
            property("fanRpm").defaultValue(0);
            property("hwType").defaultValue(0);
            property("somGpio").defaultValue(0);
            property("fdcanPsr").defaultValue(0);
            property("fdcanEcr").defaultValue(0);
            property("irReg").defaultValue(0);
            property("voltageMV").defaultValue(0);
            property("currentMA").defaultValue(0);
            property("safetyMode").defaultValue(0);
            property("alternativeExperience").defaultValue(0);
            property("heartbeatDisabled").defaultValue(0);
            property("mcuUidBytes").defaultValue(null);
            property("interruptIndex").defaultValue(0);
            property("interruptCallRate").defaultValue(-1);
            property("serialBytes").defaultValue(null);
            property("provisionBytes").defaultValue(null);
            property("codeLen").defaultValue(0);
            property("signatureChunk0").defaultValue(null);
            property("signatureChunk1").defaultValue(null);
            property("uartData").defaultValue(null);
        }
    }

}
