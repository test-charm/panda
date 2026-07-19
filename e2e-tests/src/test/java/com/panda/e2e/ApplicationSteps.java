package com.panda.e2e;

import io.cucumber.java.Before;
import io.cucumber.spring.CucumberContextConfiguration;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.testcharm.jfactory.JFactory;

@SpringBootTest(classes = CucumberConfiguration.class)
@CucumberContextConfiguration
public class ApplicationSteps {

    @Autowired
    private PandaClient client;

    @Autowired
    private JFactory jFactory;

    @Before
    public void setUp() {
        client.clearAllCanQueues();
        jFactory.clear();
    }

}
