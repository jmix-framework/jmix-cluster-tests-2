#!/usr/bin/env sh

echo 'Clearing deployment configs...'
kubectl delete -f ./k8s
echo 'Building app image...'
./gradlew bootBuildImage
echo 'Loading image...'
minikube image load docker.haulmont.com/platform/jmix-kube-tests/sample-cluster:jmix_2_0
echo 'Applying configs...'
kubectl apply -f ./k8s
echo 'Done!'