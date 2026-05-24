# Project Instructions

## Project Overview

This is a Jmix sample application for cluster behavior tests.

Cluster test beans are part of the application code under `src/main/java/.../tests/...`.
They run inside Kubernetes pods and are invoked through JMX.

`src/test/java/.../TestRunner.java` is the local JUnit orchestrator. It talks to
running pods through JMX and executes cluster test beans by name.

Kubernetes manifests live under `k8s/`.
For local development, minikube cluster lifecycle is handled by
`minikube_cluster.sh`.

## Development Rules

- Do not revert unrelated local changes.
- Keep changes focused and consistent with existing cluster-test patterns.
- Remember that changes under `src/main/java` affect code running inside pods,
  not only local JUnit code.

## Test Workflow

Run the compile check with:

```bash
./gradlew compileJava testClasses
```

If changed code runs inside the cluster application, reload the local cluster
before validating behavior:

```bash
./minikube_cluster.sh --reload
```

Run one cluster test with:

```bash
./gradlew test --tests io.jmix.samples.cluster2.TestRunner.singleClusterTest -DtestBeanName=<cluster_test_bean>
```

Run the full cluster suite only when needed:

```bash
./gradlew test --tests io.jmix.samples.cluster2.TestRunner
```

## Verification

After cluster test runs, inspect the runner XML and confirm the logs mention the
expected cluster test beans. For focused runs, check the requested bean. For full
runs, check that the expected test beans were actually invoked:

```text
build/test-results/test/TEST-io.jmix.samples.cluster2.TestRunner.xml
```
