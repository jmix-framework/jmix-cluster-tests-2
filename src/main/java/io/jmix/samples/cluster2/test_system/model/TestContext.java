package io.jmix.samples.cluster2.test_system.model;

import java.io.Serial;
import java.io.Serializable;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;


public class TestContext extends HashMap<String, Object> {

    @Serial
    private static final long serialVersionUID = 319968903883814157L;

    private final LinkedHashMap<String, NodeInfo> nodesByNames = new LinkedHashMap<>();


    public void registerNode(String name, String ip, String jmxPort) {
        nodesByNames.put(name, new NodeInfo(name, ip, jmxPort));
    }

    public NodeInfo getNodeInfo(String name) {
        return nodesByNames.get(name);
    }

    public Map<String, NodeInfo> getNodeMap() {
        return nodesByNames;
    }

    public Set<String> getNodeNames() {
        return nodesByNames.keySet();
    }


    public static class NodeInfo implements Serializable {

        @Serial
        private static final long serialVersionUID = -4716027253208866310L;

        private String name;
        private String ip;
        private String jmxPort;

        public NodeInfo(String name, String ip, String jmxPort) {
            this.name = name;
            this.ip = ip;
            this.jmxPort = jmxPort;
        }

        public String getName() {
            return name;
        }

        public String getIp() {
            return ip;
        }

        public String getJmxPort() {
            return jmxPort;
        }
    }
}
