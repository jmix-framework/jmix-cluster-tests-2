# Jmix Cluster Tests for Jmix 2.x

Project to run k8s cluster tests on Jmix 2.x app.

## Prerequisites

Common:

- JDK 21
- Docker
- kubectl

Minikube:

- minikube with `qemu2` driver
- about 6 GB RAM and 2 CPUs

Remote cluster:

- `KUBECONFIG_CONTENT` contains the remote kubeconfig file content
- `kubetestcred` exists in `jmix-cluster-tests`

## Minikube

Before tests, make sure `TestRunner.localClusterMode` is `true`

Full setup if the cluster is not installed yet:

```bash
./minikube_cluster.sh
```

OR: Rebuild and redeploy the image into an existing cluster:

```bash
./minikube_cluster.sh -r
```

Run tests:

```bash
./gradlew test --tests io.jmix.samples.cluster2.TestRunner.clusterTests
```

## Remote cluster

Make sure `TestRunner.localClusterMode` is `false`.
<p>
Put the remote kubeconfig file content into `KUBECONFIG_CONTENT`, then run:

```bash
./remote_cluster.sh --apply
./gradlew test --tests io.jmix.samples.cluster2.TestRunner.clusterTests
```
