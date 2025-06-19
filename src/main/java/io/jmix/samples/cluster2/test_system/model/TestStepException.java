package io.jmix.samples.cluster2.test_system.model;

import java.io.Serial;

public class TestStepException extends Exception {

    @Serial
    private static final long serialVersionUID = -2019687188979410104L;

    public TestStepException(Throwable cause) {
        super(cause);
    }
}
