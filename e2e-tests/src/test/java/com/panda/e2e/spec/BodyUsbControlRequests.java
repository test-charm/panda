package com.panda.e2e.spec;

import com.panda.e2e.BodyPandaClient;
import org.testcharm.jfactory.Spec;

public class BodyUsbControlRequests {

    public static class BodyUsbControlRequest extends Spec<BodyPandaClient.BodyControlRequest> {
        @Override
        public void main() {
            property("length").defaultValue((short) 0);
        }
    }

    /**
     * 0xb3: set motor speeds
     */
    public static class SetMotorSpeed extends BodyUsbControlRequest {
        @Override
        public void main() {
            property("request").defaultValue((byte) -77);       // 0xb3
            property("param2").defaultValue((short) 0);
        }
    }

    /**
     * 0xb4: enable/disable motors
     */
    public static class SetMotorEnable extends BodyUsbControlRequest {
        @Override
        public void main() {
            property("request").defaultValue((byte) -76);       // 0xb4
            property("param2").defaultValue((short) 0);
        }
    }

    /**
     * 0xc1: get hardware type
     */
    public static class GetHwType extends BodyUsbControlRequest {
        @Override
        public void main() {
            property("request").defaultValue((byte) -63);       // 0xc1
            property("param1").defaultValue((short) 0);
            property("param2").defaultValue((short) 0);
        }
    }
}
