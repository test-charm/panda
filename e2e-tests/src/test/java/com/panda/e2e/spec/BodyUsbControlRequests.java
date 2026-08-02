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

    /**
     * Body control setup — preset signature data for 0xd3/0xd4 signature commands.
     */
    public static class BodyControlSetup extends Spec<BodyControlSetup> {
        public int codeLen;
        public String signatureChunk0;
        public String signatureChunk1;
        public int ctrlModeReq;
        public int ctrlTypeSel;
        public int phaseSelection;
        public int cruiseEnabled;
        public int cruiseTarget;
        public int fieldWeakEnabled;
        public int schedulerReady;
        public int seedControlMode;
        public int hallLeftA;
        public int hallLeftB;
        public int hallLeftC;
        public int hallRightA;
        public int hallRightB;
        public int hallRightC;
        public int adcLeftPhaA;
        public int adcLeftPhaC;
        public int adcLeftDc;
        public int adcRightPhaA;
        public int adcRightPhaC;
        public int adcRightDc;
        public int adcBattery;
        public int angleMeasEna;
        public int mechAngleLeft;
        public int mechAngleRight;
        public int diagEna;
        public int errQual;
        public int errDequal;

        @Override
        public void main() {
            property("codeLen").defaultValue(0);
            property("signatureChunk0").defaultValue(null);
            property("signatureChunk1").defaultValue(null);
            property("ctrlModeReq").defaultValue(-1);
            property("ctrlTypeSel").defaultValue(-1);
            property("phaseSelection").defaultValue(-1);
            property("cruiseEnabled").defaultValue(-1);
            property("cruiseTarget").defaultValue(Integer.MIN_VALUE);
            property("fieldWeakEnabled").defaultValue(-1);
            property("schedulerReady").defaultValue(-1);
            property("seedControlMode").defaultValue(-1);
            property("hallLeftA").defaultValue(-1);
            property("hallLeftB").defaultValue(-1);
            property("hallLeftC").defaultValue(-1);
            property("hallRightA").defaultValue(-1);
            property("hallRightB").defaultValue(-1);
            property("hallRightC").defaultValue(-1);
            property("adcLeftPhaA").defaultValue(-1);
            property("adcLeftPhaC").defaultValue(-1);
            property("adcLeftDc").defaultValue(-1);
            property("adcRightPhaA").defaultValue(-1);
            property("adcRightPhaC").defaultValue(-1);
            property("adcRightDc").defaultValue(-1);
            property("adcBattery").defaultValue(-1);
            property("angleMeasEna").defaultValue(-1);
            property("mechAngleLeft").defaultValue(Integer.MIN_VALUE);
            property("mechAngleRight").defaultValue(Integer.MIN_VALUE);
            property("diagEna").defaultValue(-1);
            property("errQual").defaultValue(-1);
            property("errDequal").defaultValue(-1);
        }
    }
}
