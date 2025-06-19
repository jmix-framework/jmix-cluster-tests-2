package io.jmix.samples.cluster2.test_support.k8s;

import io.fabric8.kubernetes.client.LocalPortForward;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.lang.Nullable;

import java.io.IOException;

public class ApiPodBridge implements PodBridge {
    private static final Logger log = LoggerFactory.getLogger(ApiPodBridge.class);

    private final String name;
    private final String jmxPort;
    private final String debugPort;
    private final String nodeIp;

    private final LocalPortForward portForward;
    private final LocalPortForward debugPortForward;


    public ApiPodBridge(String name,
                        String nodeIp,
                        LocalPortForward jmxPortForward,
                        @Nullable LocalPortForward debugPortForward) {
        this.name = name;
        this.portForward = jmxPortForward;
        this.debugPortForward = debugPortForward;
        jmxPort = Integer.toString(jmxPortForward.getLocalPort());
        debugPort = debugPortForward != null ? Integer.toString(debugPortForward.getLocalPort()) : null;
        this.nodeIp = nodeIp;
    }

    @Override
    public String getName() {
        return name;
    }

    @Override
    public String getJmxPort() {
        return jmxPort;
    }

    @Nullable
    @Override
    public String getDebugPort() {
        return debugPort;
    }


    @Override
    public String getNodeIp() {
        return nodeIp;
    }

    public void destroy() {

        try {
            portForward.close();
            if (debugPortForward != null)
                debugPortForward.close();
        } catch (IOException e) {
            log.warn("Cannot close bridge '{}' port forwarders", name, e);
        }

    }

    @Override
    public String toString() {
        return "PodBridge{" +
                "pod='" + name + '\'' +
                ", port='" + jmxPort + '\'' +
                ", debugPort='" + debugPort + '\'' +
                ", nodeIp='" + nodeIp + '\'' +
                '}';
    }
}
