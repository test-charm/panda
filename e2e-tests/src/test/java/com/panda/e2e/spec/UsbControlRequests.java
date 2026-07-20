package com.panda.e2e.spec;

import com.panda.e2e.SafetyModeSteps;
import org.testcharm.jfactory.Spec;

public class UsbControlRequests {

    public static class UsbControlRequest extends Spec<SafetyModeSteps.UsbControlRequest> {
    }

    public static class SetSafetyMode extends Spec<SafetyModeSteps.UsbControlRequest> {
        @Override
        public void main() {
            property("request").defaultValue((byte) -36);
            property("param2").defaultValue((short) 0);
        }
    }

    public static class CanLoopback extends Spec<SafetyModeSteps.UsbControlRequest> {
        @Override
        public void main() {
            property("request").defaultValue((byte) -27);
            property("param2").defaultValue((short) 0);
        }
    }

    public static class Heartbeat extends Spec<SafetyModeSteps.UsbControlRequest> {
        @Override
        public void main() {
            property("request").defaultValue((byte) -13);       // 0xf3
            property("param2").defaultValue((short) 0);
        }
    }

    public static class DisableHeartbeat extends Spec<SafetyModeSteps.UsbControlRequest> {
        @Override
        public void main() {
            property("request").defaultValue((byte) -8);        // 0xf8
            property("param2").defaultValue((short) 0);
        }
    }
}
