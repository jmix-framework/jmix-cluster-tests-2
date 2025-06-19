package io.jmix.samples.cluster2.test_support.k8s;

import io.fabric8.kubernetes.api.model.Pod;
import io.fabric8.kubernetes.api.model.PodList;
import io.fabric8.kubernetes.client.Config;
import io.fabric8.kubernetes.client.KubernetesClient;
import io.fabric8.kubernetes.client.KubernetesClientBuilder;
import io.fabric8.kubernetes.client.LocalPortForward;
import io.fabric8.kubernetes.client.dsl.PodResource;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.annotation.Nullable;
import java.util.*;
import java.util.stream.Collectors;


public class K8sControlTool implements AutoCloseable {

    private static final Logger log = LoggerFactory.getLogger(K8sControlTool.class);

    public static int SCALE_TIMEOUT_MS = 120 * 1000;
    public static int SCALE_CHECKING_PERIOUD_MS = 1000;
    public static int FIRST_PORT = 49001;
    public static int FIRST_DEBUG_PORT = 50001;

    public static int INT_INNER_JMX_PORT = 9875;
    public static String INNER_JMX_PORT = Integer.toString(INT_INNER_JMX_PORT);
    public static int INT_INNER_DEBUG_PORT = 5006;
    public static String INNER_DEBUG_PORT = Integer.toString(INT_INNER_DEBUG_PORT);


    String ENV_KUBECONFIG_CONTENT = "KUBECONFIG_CONTENT";
    String NAMESPACE = "jmix-cluster-tests";
    String APP_NAME = "sample-app";
    String POD_LABEL_SELECTOR = "app=" + APP_NAME;
    String POD_STATUS_SELECTOR = "status.phase=Running";

    protected Map<String, PodBridge> bridges = new HashMap<>();
    protected static int nextPort = FIRST_PORT;
    protected static int nextDebugPort = FIRST_DEBUG_PORT;

    protected boolean debugMode;
    protected boolean localClusterMode;

    private KubernetesClient client;

    public K8sControlTool(boolean debugMode) {
        this(debugMode, false);
    }

    public K8sControlTool(boolean debugMode, boolean localClusterMode) {
        //super(debugMode, localClusterMode);
        this.localClusterMode = localClusterMode;
        this.debugMode = debugMode;
        initClient();
        syncBridges();
        Runtime.getRuntime().addShutdownHook(new Thread(this::destroy));
    }

    public K8sControlTool() {
        this(false);

    }

    protected void initClient() {
        KubernetesClientBuilder builder = new KubernetesClientBuilder();
        if (System.getenv(ENV_KUBECONFIG_CONTENT) != null && !localClusterMode) {
            log.info("Using environment variable to get kubeconfig...");
            builder.withConfig(Config.fromKubeconfig(System.getenv(ENV_KUBECONFIG_CONTENT)));
        } else {
            log.info("Local kubeconfig will be used in case of presence");
        }
        client = builder.build();
    }

    protected String podName(Pod pod) {
        return pod.getMetadata().getName();
    }

    protected PodBridge forwardPorts(String podName,
                                     int port,
                                     int localPort,
                                     @Nullable Integer debugPort,
                                     @Nullable Integer debugLocalPort) {

        PodResource podResource = client.pods()
                .inNamespace(NAMESPACE)
                .withName(podName);

        LocalPortForward jmxForward = podResource.portForward(port, localPort);

        LocalPortForward debugForward;
        if (debugLocalPort != null) {
            debugForward = podResource.portForward(Objects.requireNonNull(debugPort), debugLocalPort);
        } else {
            debugForward = null;
        }

        String podIP = podResource.get().getStatus().getPodIP();

        return new ApiPodBridge(podName, podIP, jmxForward, debugForward);
    }

    protected List<Pod> loadRunningPods() {
        PodList pods = client.pods()
                .inNamespace(NAMESPACE)
                .withLabel(POD_LABEL_SELECTOR)
                .withField("status.phase", "Running")
                .list();
        return pods.getItems();
    }

    public int getCurrentScale() {
        Integer oldScale = client.apps().deployments()
                .inNamespace(NAMESPACE)
                .withName(APP_NAME)
                .scale()
                .getSpec()
                .getReplicas();
        return oldScale != null ? oldScale : 0;
    }

    protected void doScale(int size) {
        client.apps().deployments().inNamespace(NAMESPACE).withName(APP_NAME).scale(size);
    }

    protected void syncBridges() {
        log.debug("Synchronizing pod bridges");
        List<Pod> pods = loadRunningPods();
        List<String> obsolete = new LinkedList<>(bridges.keySet());
        //add absent pod bridges
        for (Pod pod : pods) {
            String podName = podName(pod);
            if (bridges.containsKey(podName)) {
                obsolete.remove(podName);
                continue;
            }
            PodBridge bridge = forwardPorts(podName,
                    INT_INNER_JMX_PORT,
                    nextPort++,
                    debugMode ? INT_INNER_DEBUG_PORT : null,
                    debugMode ? nextDebugPort++ : null);

            bridges.put(podName, bridge);
            log.info("FORWARDING: {}", bridge);
        }
        //remove obsolete bridges
        for (String podName : obsolete) {
            (bridges.get(podName)).destroy();
            bridges.remove(podName);
        }
        log.debug("Pod bridges synchronized");
    }

    protected void awaitScaling(int desiredSize) {
        long startTime = System.currentTimeMillis();
        while (loadRunningPods().size() != desiredSize) {
            if (System.currentTimeMillis() - startTime > SCALE_TIMEOUT_MS) {
                throw new RuntimeException(
                        String.format("Scaling wait time out: deployment has not been scaled during %s seconds",
                                SCALE_TIMEOUT_MS / 1000));
            }
            try {
                Thread.sleep(SCALE_CHECKING_PERIOUD_MS);
            } catch (InterruptedException e) {
                throw new RuntimeException("Problem while waiting for deployment to be scaled", e);
            }
        }
    }

    public void scalePods(int size) {
        log.info("Scaling deployment: {} -> {}", getCurrentScale(), size);
        doScale(size);
        awaitScaling(size);
        log.info("Deployment sucessfully scaled");
        syncBridges();
    }

    public void destroy() {
        for (PodBridge bridge : bridges.values()) {
            bridge.destroy();
        }
        bridges.clear();
    }

    public int getPodCount() {
        return bridges.size();
    }

    public List<PodBridge> getPodBridges() {
        return new LinkedList<>(bridges.values());
    }

    public List<String> getPorts() {
        return bridges.values().stream().map(PodBridge::getJmxPort).collect(Collectors.toList());
    }

    public void close() {
        destroy();
    }
}
