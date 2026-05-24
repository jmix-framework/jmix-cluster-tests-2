package io.jmix.samples.cluster2.test_system.model.annotations;

import java.lang.annotation.*;

//possible improvement:app-properties substitution during the test (may be achieved through env variables)
@Target({ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
@Inherited
public @interface ClusterTest {
    String ALL_NODES = "_INIT_ALL_NODES";
    String NO_NODES = "_INIT_NO_NODES";

    boolean cleanStart() default false;

    String[] initNodes() default ALL_NODES;

    String description() default "";
}
