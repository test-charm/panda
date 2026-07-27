package com.panda.e2e.spec;

import lombok.Getter;
import lombok.Setter;
import org.testcharm.jfactory.Spec;

public class CanQueues {

    public static class CanQueue extends Spec<CanQueueData> {
    }

    @Getter
    @Setter
    public static class CanQueueData {
        private int queueNum, w_ptr, r_ptr;
    }
}
