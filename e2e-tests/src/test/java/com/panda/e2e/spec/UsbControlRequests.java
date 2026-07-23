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

    public static class GetVersion extends UsbControlRequest {
        @Override
        public void main() {
            property("request").defaultValue((byte) -42);       // 0xd6
            property("param2").defaultValue((short) 0);
        }
    }

    public static class GetPacketVersions extends UsbControlRequest {
        @Override
        public void main() {
            property("request").defaultValue((byte) -35);       // 0xdd
            property("param2").defaultValue((short) 0);
        }
    }

    public static class SetIrPower extends UsbControlRequest {
        @Override
        public void main() {
            property("request").defaultValue((byte) -80);       // 0xb0
            property("param2").defaultValue((short) 0);
        }
    }

    public static class GetHwType extends UsbControlRequest {
        @Override
        public void main() {
            property("request").defaultValue((byte) -63);       // 0xc1
            property("param2").defaultValue((short) 0);
        }
    }

    public static class SetCanBitrate extends UsbControlRequest {
        @Override
        public void main() {
            property("request").defaultValue((byte) -34);       // 0xde
        }
    }

    public static class SetCanFdAuto extends UsbControlRequest {
        @Override
        public void main() {
            property("request").defaultValue((byte) -24);       // 0xe8
        }
    }

    public static class SetCanFdNonIso extends UsbControlRequest {
        @Override
        public void main() {
            property("request").defaultValue((byte) -4);        // 0xfc
        }
    }

    public static class SetCanFdDataBitrate extends UsbControlRequest {
        @Override
        public void main() {
            property("request").defaultValue((byte) -7);        // 0xf9
        }
    }

    public static class SetClockSource extends UsbControlRequest {
        @Override
        public void main() {
            property("request").defaultValue((byte) -26);       // 0xe6
        }
    }

    public static class GetMicrosecondTimer extends UsbControlRequest {
        @Override
        public void main() {
            property("request").defaultValue((byte) -88);       // 0xa8
            property("param2").defaultValue((short) 0);
        }
    }

    public static class GetFanRpm extends UsbControlRequest {
        @Override
        public void main() {
            property("request").defaultValue((byte) -78);       // 0xb2
            property("param2").defaultValue((short) 0);
        }
    }

    public static class ReadSomGpio extends UsbControlRequest {
        @Override
        public void main() {
            property("request").defaultValue((byte) -58);       // 0xc6
            property("param2").defaultValue((short) 0);
        }
    }

    public static class GetCanHealth extends UsbControlRequest {
        @Override
        public void main() {
            property("request").defaultValue((byte) -62);       // 0xc2
            property("param2").defaultValue((short) 0);
        }
    }

    public static class SetFanPower extends UsbControlRequest {
        @Override
        public void main() {
            property("request").defaultValue((byte) -79);       // 0xb1
            property("param2").defaultValue((short) 0);
        }
    }

    public static class ResetSt extends UsbControlRequest {
        @Override
        public void main() {
            property("request").defaultValue((byte) -40);       // 0xd8
            property("param2").defaultValue((short) 0);
        }
    }

    public static class RequestDeepSleep extends UsbControlRequest {
        @Override
        public void main() {
            property("request").defaultValue((byte) -75);       // 0xb5
            property("param1").defaultValue((short) 0);
            property("param2").defaultValue((short) 0);
        }
    }
}
