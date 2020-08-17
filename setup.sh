#!/bin/bash
#title           :setup.sh
#description     :This script will setup the infrastructure required for a sample NodeJS App to run in K8S
#author		       :Chihab Eddine Djaidja
#email           :chihab.djaidja@gmail.com
#usage		       :setup.sh -t [DOCKERHUB_PRIVATE_TOKEN] -d [MINIKUBE_VM_DRIVER]

dockerhub_private_token=
minikube_vm_driver="kvm2"
margs=4 # mandatory number of args
os_uname=$(uname -s)
os_version=$(uname -v)

main() {
  verify_programs sed uname kubectl minikube helm base64
  setup_prod_cluster
  update_secrets_yamls
  setup_dev_cluster
  echo "Setup: sleeping 30 seconds while waiting for ingress controller to boot up in dev cluster"
  sleep 30
  deploy_jenkins
  print_hosts
}

setup_dev_cluster() {
  echo "Setup: setting up dev cluster"
  minikube start -p=dev-cluster --driver=$minikube_vm_driver --memory='2000mb' --disk-size='10000mb' --addons=ingress --dns-domain=ppro.dev --embed-certs=true
  echo "Setup: creating RBAC objects for helm in dev cluster"
  kubectl apply -f ./jenkins/rbac.yaml | indent
}

setup_prod_cluster() {
  echo "Setup: setting up prod cluster"
  minikube start -p=prod-cluster --driver=$minikube_vm_driver --memory='2000mb' --disk-size='10000mb' --addons=ingress --dns-domain=ppro.prod --embed-certs=true
  echo "Setup: creating RBAC objects for helm in prod cluster"
  kubectl apply -f ./jenkins/rbac.yaml | indent
}

# Deploy jenkins chart to dev cluster
deploy_jenkins() {
  echo "Setup: deploying Jenkins Chart to dev cluster"
  echo "Setting up Jenkins secrets" | indent
  kubectl apply -f ./jenkins/secrets.yaml | indent
  helm repo add stable https://kubernetes-charts.storage.googleapis.com/
  helm install jenkins stable/jenkins --version=2.5.0 \
    --set master.containerEnv[0].name=DEV_CLUSTER_IP \
    --set master.containerEnv[0].value=$(minikube ip --profile=dev-cluster) \
    --set master.containerEnv[1].name=PROD_CLUSTER_IP \
    --set master.containerEnv[1].value=$(minikube ip --profile=prod-cluster) \
    -f ./jenkins/jenkins.yaml
}

# Inject secrets to yaml template
update_secrets_yamls() {
  encoded_config=$(cat ~/.kube/config | base64 -w 0)
  cat ./jenkins/secrets.yaml.tpl | sed -e "s/{{CONFIG_DATA}}/$encoded_config/g" -e "s/{{DOCKERHUB_PRIVATE_TOKEN}}/$dockerhub_private_token/g" >./jenkins/secrets.yaml
}

# Verify that all required programs are present in the system
verify_programs() {
  echo "Setup: running: on $os_uname ($os_version)"
  list_programs=$(echo "$*" | sort -u | tr "\n" " ")
  echo "Setup: verify $list_programs"
  programs_ok=1
  for prog in "$@"; do
    if [[ -z $(which "$prog") ]]; then
      echo "Setup needs [$prog] but this program cannot be found on this $os_uname machine"
      programs_ok=0
    fi
  done
  if [[ $programs_ok -eq 1 ]]; then
    echo "Setup: check required programs OK"
  fi
}

print_hosts() {
  echo "Setup: Please update your /etc/hosts with the following lines in order to access the services"
  echo "##############################################" | indent
  echo "$(minikube ip --profile=dev-cluster) jenkins.ppro.dev" | indent
  echo "$(minikube ip --profile=dev-cluster) nodejs-hello.ppro.dev" | indent
  echo "$(minikube ip --profile=prod-cluster) jenkins.ppro.prod" | indent
  echo "##############################################" | indent
}

# Ensures that the number of passed args are at least equals
margs_check() {
  if [ $1 -lt $margs ]; then
    echo "Wrong number of passed arguments"
    usage
    exit 1 # error
  fi
}

# Prints usage
usage() {
  echo "USAGE: ./setup.sh -t [DOCKERHUB_PRIVATE_TOKEN] -d [MINIKUBE_VM_DRIVER]"
}

cleanup () {
  rm ./jenkins/secrets.yaml
}

# Indent output of commands
indent() { sed 's/^/       /'; }

# Check number of args
margs_check $#

# Parse args while-loop
while [ "$1" != "" ]; do
  case $1 in
  -t | --dockerhub-token)
    shift
    dockerhub_private_token=$1
    ;;
  -d | --minikube-driver)
    shift
    minikube_vm_driver=$1
    ;;
  *)
    echo "Setup: illegal option $1"
    usage
    exit 1 # error
    ;;
  esac
  shift
done

# Run main function
main
trap cleanup EXIT

exit 0