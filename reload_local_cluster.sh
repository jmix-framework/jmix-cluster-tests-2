#!/usr/bin/env sh

echo 'Clearing deployment configs...'
kubectl delete -f ./k8s -n='jmix-cluster-tests'
echo 'Building app image...'
./gradlew bootBuildImage
echo 'Reloading image...'
minikube image rm docker.haulmont.com/platform/jmix-kube-tests/sample-cluster:jmix_2_0
minikube image load docker.haulmont.com/platform/jmix-kube-tests/sample-cluster:jmix_2_0
echo 'Applying configs...'
kubectl apply -f ./k8s  -n='jmix-cluster-tests'
echo 'Done!'