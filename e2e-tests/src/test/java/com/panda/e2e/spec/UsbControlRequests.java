package com.panda.e2e.spec;

import com.panda.e2e.SafetyModeSteps;
import org.testcharm.jfactory.Spec;

public class UsbControlRequests {

    public static class UsbControlRequest extends Spec<SafetyModeSteps.UsbControlRequest> {
    }

    public static class SetSafetyMode extends UsbControlRequest {
        @Override
        public void main() {
            property("request").defaultValue((byte) -36);
            property("param2").defaultValue((short) 0);
        }
    }

    public static class CanLoopback extends UsbControlRequest {
        @Override
        public void main() {
            property("request").defaultValue((byte) -27);
            property("param2").defaultValue((short) 0);
        }
    }

    public static class Heartbeat extends UsbControlRequest {
        @Override
        public void main() {
            property("request").defaultValue((byte) -13);       // 0xf3
            property("param2").defaultValue((short) 0);
        }
    }

    public static class DisableHeartbeat extends UsbControlRequest {
        @Override
        public void main() {
            property("request").defaultValue((byte) -8);        // 0xf8
            property("param2").defaultValue((short) 0);
        }
    }

    public static class GetHealth extends UsbControlRequest {
        @Override
        public void main() {
            property("request").defaultValue((byte) -46);       // 0xd2
            property("param1").defaultValue((short) 0);
            property("param2").defaultValue((short) 0);
        }
    }
}
