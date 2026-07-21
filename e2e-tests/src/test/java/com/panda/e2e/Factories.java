package com.panda.e2e;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.testcharm.jfactory.CompositeDataRepository;
import org.testcharm.jfactory.JFactory;
import org.testcharm.jfactory.MemoryDataRepository;
import org.testcharm.jfactory.Spec;
import org.testcharm.util.Classes;

@Configuration
public class Factories {

    @Bean
    public JFactory createJFactory(PandaClient client) {
        var jFactory = new JFactory(new CompositeDataRepository(new MemoryDataRepository())
                .registerByType(SafetyModeSteps.UsbControlRequest.class, new UsbControlRequestDataRepository(client))
                .registerByType(SafetyModeSteps.CanSendRequest.class, new CanSendRequestDataRepository(client))
                .registerByType(SafetyModeSteps.ControlSetup.class, new TimerSetupDataRepository(client))
        );
        Classes.subTypesOf(Spec.class, "com.panda.e2e.spec")
                .forEach(spec -> jFactory.register((Class) spec));
        return jFactory;
    }

    public static class UsbControlRequestDataRepository extends MemoryDataRepository {

        private final PandaClient client;

        public UsbControlRequestDataRepository(PandaClient client) {
            this.client = client;
        }

        @Override
        public void save(Object object) {
            super.save(object);
            var request = (SafetyModeSteps.UsbControlRequest) object;
            client.controlWrite(request.request, request.param1, request.param2);
        }
    }

    public static class CanSendRequestDataRepository extends MemoryDataRepository {
        private final PandaClient client;

        public CanSendRequestDataRepository(PandaClient client) {
            this.client = client;
        }

        @Override
        public void save(Object object) {
            super.save(object);
            var request = (SafetyModeSteps.CanSendRequest) object;
            client.canSend(request.address, request.data.getBytes(), request.bus);
        }
    }

    public static class TimerSetupDataRepository extends MemoryDataRepository {
        private final PandaClient client;

        public TimerSetupDataRepository(PandaClient client) {
            this.client = client;
        }

        @Override
        public void save(Object object) {
            super.save(object);
            var setup = (SafetyModeSteps.ControlSetup) object;
            if (setup.timerValue != 0) {
                client.setMicrosecondTimer(setup.timerValue);
            }
            if (setup.fanRpm != 0) {
                client.setFanRpm(setup.fanRpm);
            }
            if (setup.hwType != 0) {
                client.setHwType(setup.hwType);
            }
            if (setup.gitversion != null) {
                client.setGitversion(setup.gitversion);
            }
        }
    }
}
