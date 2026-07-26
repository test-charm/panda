package com.panda.e2e.spec;

import com.panda.e2e.PandaSteps;
import org.testcharm.jfactory.Spec;

public class ControlSetups {

    public static class ControlSetup extends Spec<PandaSteps.ControlSetup> {
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
            property("heartbeatCounter").defaultValue(Long.MIN_VALUE);
            property("safetyModeCnt").defaultValue(Long.MIN_VALUE);
            property("mcuUidBytes").defaultValue(null);
            property("interruptIndex").defaultValue(0);
            property("interruptCallRate").defaultValue(-1);
            property("serialBytes").defaultValue(null);
            property("provisionBytes").defaultValue(null);
            property("codeLen").defaultValue(0);
            property("signatureChunk0").defaultValue(null);
            property("signatureChunk1").defaultValue(null);
            property("uartData").defaultValue(null);
            property("relayMalfunctionVal").defaultValue(-1);
            property("harnessStatus").defaultValue(0);
            property("sbu1VoltageMV").defaultValue(-1);
            property("sbu2VoltageMV").defaultValue(-1);
            property("relayDriven").defaultValue(-1);
            property("somUartWptr").defaultValue(0);
            property("ignitionLine").defaultValue(0);
            property("ignitionCan").defaultValue(-1);
            property("controlsAllowed").defaultValue(-1);
            property("registerDivergent").defaultValue(-1);
        }
    }

}
