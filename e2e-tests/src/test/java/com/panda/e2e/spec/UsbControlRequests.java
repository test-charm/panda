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

    public static class SetCanMode extends UsbControlRequest {
        @Override
        public void main() {
            property("request").defaultValue((byte) -37);       // 0xdb
            property("param2").defaultValue((short) 0);
        }
    }

    public static class DriveRelay extends UsbControlRequest {
        @Override
        public void main() {
            property("request").defaultValue((byte) -59);       // 0xc5
            property("param2").defaultValue((short) 0);
        }
    }

    public static class SetPowerSaveState extends UsbControlRequest {
        @Override
        public void main() {
            property("request").defaultValue((byte) -25);       // 0xe7
            property("param2").defaultValue((short) 0);
        }
    }

    public static class SetAlternativeExperience extends UsbControlRequest {
        @Override
        public void main() {
            property("request").defaultValue((byte) -33);       // 0xdf
            property("param2").defaultValue((short) 0);
        }
    }

    public static class SetSiren extends UsbControlRequest {
        @Override
        public void main() {
            property("request").defaultValue((byte) -10);       // 0xf6
            property("param2").defaultValue((short) 0);
        }
    }

    public static class ResetCanComms extends UsbControlRequest {
        @Override
        public void main() {
            property("request").defaultValue((byte) -64);       // 0xc0
            property("param1").defaultValue((short) 0);
            property("param2").defaultValue((short) 0);
        }
    }

    public static class ClearCanRing extends UsbControlRequest {
        @Override
        public void main() {
            property("request").defaultValue((byte) -15);       // 0xf1
            property("param2").defaultValue((short) 0);
        }
    }
}
