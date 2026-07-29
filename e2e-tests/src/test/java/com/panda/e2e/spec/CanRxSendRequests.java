package com.panda.e2e.spec;

import com.panda.e2e.PandaSteps;
import org.testcharm.jfactory.Spec;

public class CanRxSendRequests {

    public static class CanRxSendRequest extends Spec<PandaSteps.CanRxSendRequest> {

    }

    public static class NormalCanRxSendRequest extends CanRxSendRequest {
        @Override
        public void main() {
            property("rxf0sBus").defaultValue(0);
            property("f0gi").defaultValue(0);
            property("f0fl").defaultValue(1);
            property("full").defaultValue(0);
            property("irBus").defaultValue(0);
            property("rf0n").defaultValue(1);
            property("canNumber").defaultValue(0);
        }
    }
}
