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
    private PandaClient pandaClient;

    @Autowired
    private BodyPandaClient bodyClient;

    @Autowired
    private JFactory jFactory;

    @Before
    public void setUp() {
        pandaClient.clearAll();
        bodyClient.clearAll();
        jFactory.clear();
    }

}
