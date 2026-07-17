package com.panda.e2e.spec;

import com.panda.e2e.steps.SafetyModeSteps;
import org.testcharm.jfactory.Spec;

public class UsbControlRequests {

    public static class SetSafetyMode extends Spec<SafetyModeSteps.UsbControlRequest> {
        @Override
        public void main() {
            property("request").defaultValue((byte) -36);
            property("param2").defaultValue((short) 0);
        }
    }
}
