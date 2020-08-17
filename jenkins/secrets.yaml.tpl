apiVersion: v1
kind: Secret
metadata:
  name: "jenkins-at-prod-k8s"
  labels:
    "jenkins.io/credentials-type": "secretFile"
  annotations:
    "jenkins.io/credentials-description" : "secret file credential for prod Kubernetes"
type: Opaque
stringData:
  filename: config
data:
  data: {{CONFIG_DATA}}
---
apiVersion: v1
kind: Secret
metadata:
  name: "shivox-at-dockerhub"
  labels:
    "jenkins.io/credentials-type": "secretText"
  annotations:
    "jenkins.io/credentials-description" : "secret token credential for Dockerhub"
type: Opaque
stringData:
  text: {{DOCKERHUB_PRIVATE_TOKEN}}