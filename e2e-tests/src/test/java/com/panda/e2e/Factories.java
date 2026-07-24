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
                .registerByType(SafetyModeSteps.ControlSetup.class, new ControlSetupDataRepository(client))
        );
        Classes.subTypesOf(Spec.class, "com.panda.e2e.spec")
                .forEach(spec -> jFactory.register((Class) spec));
        return jFactory;
    }

    private static byte[] hexToBytes(String hex) {
        byte[] bytes = new byte[hex.length() / 2];
        for (int i = 0; i < bytes.length; i++) {
            bytes[i] = (byte) Integer.parseInt(hex.substring(i * 2, i * 2 + 2), 16);
        }
        return bytes;
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

    public static class ControlSetupDataRepository extends MemoryDataRepository {
        private final PandaClient client;

        public ControlSetupDataRepository(PandaClient client) {
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
            if (setup.somGpio != 0) {
                client.setSomGpio(setup.somGpio);
            }
            if (setup.voltageMV != 0) {
                client.setVoltageMV(setup.voltageMV);
            }
            if (setup.currentMA != 0) {
                client.setCurrentMA(setup.currentMA);
            }
            if (setup.safetyMode != 0) {
                client.setCurrentSafetyMode(setup.safetyMode);
            }
            if (setup.alternativeExperience != 0) {
                client.setAlternativeExperience(setup.alternativeExperience);
            }
            if (setup.heartbeatDisabled != 0) {
                client.setHeartbeatDisabled(setup.heartbeatDisabled);
            }
            if (setup.mcuUidBytes != null) {
                client.setMcuUid(hexToBytes(setup.mcuUidBytes));
            }
            if (setup.serialBytes != null) {
                client.setSerial(hexToBytes(setup.serialBytes));
            }
            if (setup.provisionBytes != null) {
                client.setProvision(hexToBytes(setup.provisionBytes));
            }
            if (setup.codeLen != 0) {
                client.setAppCodeLen(setup.codeLen);
            }
            if (setup.signatureChunk0 != null) {
                client.setSignatureChunk(0, hexToBytes(setup.signatureChunk0));
            }
            if (setup.signatureChunk1 != null) {
                client.setSignatureChunk(1, hexToBytes(setup.signatureChunk1));
            }
            if (setup.interruptCallRate != -1) {
                client.setInterruptCallRate(setup.interruptIndex, setup.interruptCallRate);
            }
            if (setup.fdcanPsr != 0) {
                client.setFdcanPsr(0, setup.fdcanPsr);
            }
            if (setup.fdcanEcr != 0) {
                client.setFdcanEcr(0, setup.fdcanEcr);
            }
            if (setup.fdcanPsr != 0 || setup.fdcanEcr != 0 || setup.irReg != 0) {
                client.callUpdateCanHealthPkt(0, setup.irReg);
            }
        }
    }
}
