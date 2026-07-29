package com.panda.e2e.spec;

import com.panda.e2e.PandaSteps;
import org.testcharm.jfactory.Spec;

public class CanRxInjectRequests {

    public static class CanRxInjectRequest extends Spec<PandaSteps.CanRxInjectRequest> {
    }

    public static class StandardFrameRequest extends CanRxInjectRequest {
        @Override
        public void main() {
            property("extended").defaultValue(false);
            property("canfdFrame").defaultValue(false);
            property("brsFrame").defaultValue(false);
            property("dataLenCode").defaultValue(8);
            property("elementIndex").defaultValue(0);
        }
    }

    public static class StandardRxFrame extends StandardFrameRequest {
    }

    public static class ExtendedFrameRequest extends CanRxInjectRequest {
        @Override
        public void main() {
            property("extended").defaultValue(true);
            property("canfdFrame").defaultValue(false);
            property("brsFrame").defaultValue(false);
            property("dataLenCode").defaultValue(8);
            property("elementIndex").defaultValue(0);
        }
    }

    public static class ExtendedRxFrame extends ExtendedFrameRequest {

    }

    public static class CanFdFrameRequest extends CanRxInjectRequest {
        @Override
        public void main() {
            property("extended").defaultValue(false);
            property("canfdFrame").defaultValue(true);
            property("brsFrame").defaultValue(false);
            property("dataLenCode").defaultValue(8);
            property("elementIndex").defaultValue(0);
        }
    }

    public static class CanFdRxFrame extends CanFdFrameRequest {

    }

    public static class BrsFrameRequest extends CanRxInjectRequest {
        @Override
        public void main() {
            property("extended").defaultValue(false);
            property("canfdFrame").defaultValue(true);
            property("brsFrame").defaultValue(true);
            property("dataLenCode").defaultValue(8);
            property("elementIndex").defaultValue(0);
        }
    }

    public static class BrsRxFrame extends BrsFrameRequest {
    }
}
