#!/usr/bin/env sh

#Start minikube cluster
# todo possibility to clear/delete minikube vm before starting
#minikube delete
MINIKUBE_MEMORY_MB="${MINIKUBE_MEMORY_MB:-10240}"
MINIKUBE_CPUS="${MINIKUBE_CPUS:-4}"
RECREATE_MINIKUBE="${RECREATE_MINIKUBE:-true}"

if [ "$RECREATE_MINIKUBE" = "true" ]; then
  echo 'Deleting existing minikube profile...'
  minikube delete
fi

echo "Starting cluster with ${MINIKUBE_MEMORY_MB} MB memory and ${MINIKUBE_CPUS} CPUs..."
# "--network builtin" - optional
minikube start --vm-driver=qemu2 --network builtin --memory="$MINIKUBE_MEMORY_MB" --cpus="$MINIKUBE_CPUS"
minikube addons enable ingress
kubectl config use-context minikube
minikube dashboard > /dev/null 2>&1 &

#todo clear and apply configs not needed in case of minikube delete invoked
echo 'Clearing deployment configs...'
kubectl delete -f ./k8s
#kubectl delete namespace jmix-cluster-tests
kubectl create namespace jmix-cluster-tests
echo 'Building app image...'
./gradlew bootBuildImage
echo 'Pushing image to gitlab repository'
docker push docker.haulmont.com/platform/jmix-kube-tests/sample-cluster:jmix_2_0
echo 'Loading image...'
minikube image load docker.haulmont.com/platform/jmix-kube-tests/sample-cluster:jmix_2_0
echo 'Applying configs...'
kubectl apply -f ./k8s
echo 'Done!'
