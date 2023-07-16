package io.jmix.samples.cluster2.test_system.model.step;

import io.jmix.samples.cluster2.test_system.model.TestContext;
import io.jmix.samples.cluster2.test_system.model.TestStepException;

public interface TestAction {
    void doAction(TestContext context) throws TestStepException;
}
