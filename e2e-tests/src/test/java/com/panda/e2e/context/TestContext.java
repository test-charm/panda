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

    public PandaClient getClient() { return client; }
    public void setClient(PandaClient client) { this.client = client; }
    public List<CanMessage> getReceivedMessages() { return receivedMessages; }
    public void setReceivedMessages(List<CanMessage> msgs) { this.receivedMessages = msgs; }
}
