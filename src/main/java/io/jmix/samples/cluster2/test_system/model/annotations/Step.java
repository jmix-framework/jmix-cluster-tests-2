package io.jmix.samples.cluster2.test_system.model.annotations;

import java.lang.annotation.*;

@Target({ElementType.METHOD})
@Retention(RetentionPolicy.RUNTIME)
@Inherited
public @interface Step {
    int order();

    /**
     * Node names to run this step on.
     * Empty value means that step will be performed on all existing at step time nodes.
     */
    String[] nodes() default {};

    String description() default "";
}
