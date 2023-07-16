package io.jmix.samples.cluster2.test_system.model.annotations;

import java.lang.annotation.*;

@Target({ElementType.METHOD})
@Retention(RetentionPolicy.RUNTIME)
@Inherited
public @interface AfterStep {

    /**
     * @return whether annotated method should be executed in case of step failed
     */
    boolean alwaysRun() default true;
}



