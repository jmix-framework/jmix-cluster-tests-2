#!/usr/bin/env sh

#Start minikube cluster
# todo Uncomment to remove minikube before
#echo "Delete old minikube"
#minikube delete
#echo 'Clear old network'
#podman network rm minikube
echo 'Starting cluster...'
minikube start --vm-driver=podman
#--vm-driver=podman selected because of https://github.com/kubernetes/minikube/issues/15274 virtualbox can be used otherwise
minikube addons enable ingress
kubectl config use-context minikube
minikube dashboard > /dev/null 2>&1 &

echo 'Clearing deployment configs...'
kubectl delete -f ./k8s
#kubectl delete namespce jmix-cluster-tests
kubectl create namespace jmix-cluster-tests
echo 'Building app image...'
./gradlew bootBuildImage
echo 'Pushing image to gitlab repository'
podman push docker.haulmont.com/platform/jmix-kube-tests/sample-cluster:jmix_2_0
echo 'Loading image...'
minikube image load docker.haulmont.com/platform/jmix-kube-tests/sample-cluster:jmix_2_0
echo 'Applying configs...'
kubectl apply -f ./k8s
echo 'Done!'