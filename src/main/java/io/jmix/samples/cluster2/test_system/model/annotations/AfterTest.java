package io.jmix.samples.cluster2.test_system.model.annotations;

import java.lang.annotation.*;

//possible improvement: node selection
@Target({ElementType.METHOD})
@Retention(RetentionPolicy.RUNTIME)
@Inherited
public @interface AfterTest {

    /**
     * @return whether annotated method should be executed in case of test failed
     */
    boolean alwaysRun() default true;
}
