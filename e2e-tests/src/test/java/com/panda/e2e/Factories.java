package com.panda.e2e;

import com.panda.e2e.spec.BodyUsbControlRequests;
import com.panda.e2e.spec.CanQueues;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.testcharm.jfactory.CompositeDataRepository;
import org.testcharm.jfactory.JFactory;
import org.testcharm.jfactory.MemoryDataRepository;
import org.testcharm.jfactory.Spec;
import org.testcharm.util.Classes;

import java.nio.charset.StandardCharsets;

@Configuration
public class Factories {

    @Bean
    public JFactory createJFactory(PandaClient pandaClient, BodyPandaClient bodyPandaClient) {
        var jFactory = new JFactory(new CompositeDataRepository(new MemoryDataRepository())
                .registerByType(PandaSteps.UsbControlRequest.class, new UsbControlRequestDataRepository(pandaClient))
                .registerByType(PandaSteps.CanSendRequest.class, new CanSendRequestDataRepository(pandaClient))
                .registerByType(PandaSteps.ControlSetup.class, new ControlSetupDataRepository(pandaClient))
                .registerByType(CanQueues.CanQueueData.class, new CanQueueDataRepository(pandaClient))
                .registerByType(PandaSteps.CanRxInjectRequest.class, new CanRxInjectRequestDataRepository(pandaClient))
                .registerByType(BodyUsbControlRequests.BodyControlSetup.class, new BodyControlSetupDataRepository(bodyPandaClient))
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
            var request = (PandaSteps.UsbControlRequest) object;
            client.controlWrite(request.request, request.param1, request.param2, request.length);
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
            var request = (PandaSteps.CanSendRequest) object;
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
            var setup = (PandaSteps.ControlSetup) object;
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
            if (setup.heartbeatCounter != Long.MIN_VALUE) {
                client.setHeartbeatCounter((int) setup.heartbeatCounter);
            }
            if (setup.safetyModeCnt != Long.MIN_VALUE) {
                client.setSafetyModeCnt((int) setup.safetyModeCnt);
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
            if (setup.uartData != null) {
                client.uartPush(setup.uartData.getBytes());
            }
            if (setup.relayMalfunctionVal != -1) {
                client.setRelayMalfunction(setup.relayMalfunctionVal);
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
            if (setup.harnessStatus != 0) {
                client.setHarnessStatus(setup.harnessStatus);
            }
            if (setup.sbu1VoltageMV != -1) {
                client.setSbu1VoltageMV(setup.sbu1VoltageMV);
            }
            if (setup.sbu2VoltageMV != -1) {
                client.setSbu2VoltageMV(setup.sbu2VoltageMV);
            }
            if (setup.relayDriven != -1) {
                client.setRelayDriven(setup.relayDriven);
            }
            if (setup.somUartWptr != 0) {
                client.setSomUartWptr(setup.somUartWptr);
            }
            if (setup.ignitionLine != 0) {
                client.setIgnitionLine(setup.ignitionLine != 0);
            }
            if (setup.ignitionCan != -1) {
                client.setIgnitionCan(setup.ignitionCan != 0);
            }
            if (setup.controlsAllowed != -1) {
                client.setControlsAllowed(setup.controlsAllowed);
            }
            if (setup.registerDivergent != -1) {
                client.setRegisterDivergent(setup.registerDivergent);
            }
        }
    }

    public static class CanQueueDataRepository extends MemoryDataRepository {
        private final PandaClient client;

        public CanQueueDataRepository(PandaClient client) {
            this.client = client;
        }

        @Override
        public void save(Object object) {
            super.save(object);
            var queue = (CanQueues.CanQueueData) object;
            client.setCanQueueState(queue.getQueueNum(), queue.getW_ptr(), queue.getR_ptr());
        }
    }

    public static class CanRxInjectRequestDataRepository extends MemoryDataRepository {
        private final PandaClient client;

        public CanRxInjectRequestDataRepository(PandaClient client) {
            this.client = client;
        }

        @Override
        public void save(Object object) {
            super.save(object);
            var request = (PandaSteps.CanRxInjectRequest) object;
            byte[] data = request.data != null
                    ? request.data.getBytes(StandardCharsets.UTF_8)
                    : new byte[0];
            client.writeRxFifo(request.bus, request.elementIndex,
                    request.extended, request.address,
                    request.canfdFrame, request.brsFrame,
                    request.dataLenCode, data);
        }
    }

    public static class BodyControlSetupDataRepository extends MemoryDataRepository {
        private final BodyPandaClient client;

        public BodyControlSetupDataRepository(BodyPandaClient client) {
            this.client = client;
        }

        @Override
        public void save(Object object) {
            super.save(object);
            var setup = (BodyUsbControlRequests.BodyControlSetup) object;
            if (setup.codeLen != 0) {
                client.setAppCodeLen(setup.codeLen);
            }
            if (setup.signatureChunk0 != null) {
                client.setSignatureChunk(0, hexToBytes(setup.signatureChunk0));
            }
            if (setup.signatureChunk1 != null) {
                client.setSignatureChunk(1, hexToBytes(setup.signatureChunk1));
            }
            if (setup.ctrlModeReq != -1) {
                client.setCtrlModeReq(setup.ctrlModeReq);
            }
            if (setup.ctrlTypeSel != -1) {
                client.setCtrlTypeSel(setup.ctrlTypeSel);
            }
            if (setup.phaseSelection != -1) {
                client.setPhaseSelection(setup.phaseSelection);
            }
            if (setup.cruiseEnabled != -1) {
                client.setCruiseEnabled(setup.cruiseEnabled != 0);
            }
            if (setup.cruiseTarget != Integer.MIN_VALUE) {
                client.setCruiseTarget(setup.cruiseTarget);
            }
            if (setup.fieldWeakEnabled != -1) {
                client.setFieldWeakEnabled(setup.fieldWeakEnabled != 0);
            }
            if (setup.schedulerReady != -1) {
                client.setSchedulerReady(setup.schedulerReady != 0);
            }
            if (setup.seedControlMode != -1) {
                client.seedControlMode(setup.seedControlMode);
            }
            if (setup.hallLeftA != -1 || setup.hallLeftB != -1 || setup.hallLeftC != -1 ||
                    setup.hallRightA != -1 || setup.hallRightB != -1 || setup.hallRightC != -1) {
                client.setHallStates(
                        setup.hallLeftA != 0,
                        setup.hallLeftB != 0,
                        setup.hallLeftC != 0,
                        setup.hallRightA != 0,
                        setup.hallRightB != 0,
                        setup.hallRightC != 0
                );
            }
            if (setup.adcLeftPhaA != -1 || setup.adcLeftPhaC != -1 || setup.adcLeftDc != -1
                    || setup.adcRightPhaA != -1 || setup.adcRightPhaC != -1 || setup.adcRightDc != -1
                    || setup.adcBattery != -1) {
                client.setAdcRawValues(
                        Math.max(setup.adcLeftPhaA, 0),
                        Math.max(setup.adcLeftPhaC, 0),
                        Math.max(setup.adcLeftDc, 0),
                        Math.max(setup.adcRightPhaA, 0),
                        Math.max(setup.adcRightPhaC, 0),
                        Math.max(setup.adcRightDc, 0),
                        Math.max(setup.adcBattery, 0)
                );
            }
            if (setup.angleMeasEna != -1) {
                client.setAngleMeasEna(setup.angleMeasEna != 0);
            }
            if (setup.mechAngleLeft != Integer.MIN_VALUE || setup.mechAngleRight != Integer.MIN_VALUE) {
                client.setMechAngle(
                        setup.mechAngleLeft != Integer.MIN_VALUE ? setup.mechAngleLeft : 0,
                        setup.mechAngleRight != Integer.MIN_VALUE ? setup.mechAngleRight : 0
                );
            }
            if (setup.diagEna != -1) {
                client.setDiagEna(setup.diagEna != 0);
            }
            if (setup.errQual != -1 || setup.errDequal != -1) {
                client.setErrQual(
                        setup.errQual != -1 ? setup.errQual : 1280,
                        setup.errDequal != -1 ? setup.errDequal : 48000
                );
            }
        }
    }
}
