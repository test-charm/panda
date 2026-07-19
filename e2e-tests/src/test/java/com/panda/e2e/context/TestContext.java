package com.panda.e2e.context;

import com.panda.e2e.client.PandaClient;
import com.panda.e2e.client.PandaClient.CanMessage;

import java.util.List;

/**
 * Shared test context (Cucumber World) — holds the panda client and received data.
 */
public class TestContext {
    private PandaClient client;
    private List<CanMessage> receivedMessages;
    private int pipelineResult;  // 0=allowed, 1=blocked from can_send pipeline
    private int safetyTxBlockedBefore;  // counter baseline before send

    public PandaClient getClient() { return client; }
    public void setClient(PandaClient client) { this.client = client; }
    public List<CanMessage> getReceivedMessages() { return receivedMessages; }
    public void setReceivedMessages(List<CanMessage> msgs) { this.receivedMessages = msgs; }

    public int getPipelineResult() { return pipelineResult; }
    public void setPipelineResult(int result) { this.pipelineResult = result; }
    public int getSafetyTxBlockedBefore() { return safetyTxBlockedBefore; }
    public void setSafetyTxBlockedBefore(int val) { this.safetyTxBlockedBefore = val; }
}
