package com.panda.e2e.spec;

import com.panda.e2e.PandaSteps;
import org.testcharm.jfactory.Spec;

public class SpiControlRequests {

    public static class SpiControlRequest extends Spec<PandaSteps.SpiControlRequest> {
    }

    public static class SpiProcessHeader extends SpiControlRequest {
        @Override
        public void main() {
            property("state").defaultValue(0);
            property("rxBufOffset").defaultValue(0);
            property("txDone").defaultValue(false);
        }
    }

    public static class SpiProcessData extends SpiControlRequest {
        @Override
        public void main() {
            property("state").defaultValue(0);
            property("rxBufOffset").defaultValue(0);
            property("rxBufHex").defaultValue("5A AB 00 00 04 00 5E");
            property("txDone").defaultValue(true);
            property("rxDataBufOffset").defaultValue(7);
            property("txReady").defaultValue(false);
        }
    }
}
