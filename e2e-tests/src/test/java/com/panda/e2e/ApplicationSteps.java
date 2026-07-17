package com.panda.e2e;

import io.cucumber.spring.CucumberContextConfiguration;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest(classes = CucumberConfiguration.class)
@CucumberContextConfiguration
public class ApplicationSteps {

}
