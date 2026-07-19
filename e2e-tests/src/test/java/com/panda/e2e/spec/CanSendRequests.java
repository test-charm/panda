package com.panda.e2e.spec;

import com.panda.e2e.SafetyModeSteps;
import org.testcharm.jfactory.Spec;

public class CanSendRequests {

    public static class CanSendRequest extends Spec<SafetyModeSteps.CanSendRequest> {
    }

    public static class PowerTrainBusRequest extends Spec<SafetyModeSteps.CanSendRequest> {
        @Override
        public void main() {
            property("bus").defaultValue(0);
        }
    }

    public static class PowerTrainBusBlockedRequest extends Spec<SafetyModeSteps.CanSendRequest> {
        @Override
        public void main() {
            property("address").defaultValue(256);
            property("bus").defaultValue(0);
        }
    }

}
