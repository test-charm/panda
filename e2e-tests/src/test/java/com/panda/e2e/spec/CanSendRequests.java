package com.panda.e2e.spec;

import com.panda.e2e.SafetyModeSteps;
import org.testcharm.jfactory.Spec;
import org.testcharm.jfactory.Trait;

public class CanSendRequests {

    public static class BlockedAddressRequest extends Spec<SafetyModeSteps.CanSendRequest> {
        @Override
        public void main() {
            property("address").defaultValue(256);
        }

        @Trait("PowerTrainBus")
        public void powerTrainBus() {
            property("bus").defaultValue(0);
        }
    }

    public static class PowerTrainBusRequest extends Spec<SafetyModeSteps.CanSendRequest> {
        @Override
        public void main() {
            property("bus").defaultValue(0);
        }
    }

}
