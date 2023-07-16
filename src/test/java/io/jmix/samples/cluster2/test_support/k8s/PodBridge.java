package io.jmix.samples.cluster2.test_support.k8s;

import javax.annotation.Nullable;

public interface PodBridge {
    String getName();

    String getPort();

    @Nullable
    String getDebugPort();

    /**
     * Closes port-forwarding connections and frees related resources
     */
    void destroy();
}
