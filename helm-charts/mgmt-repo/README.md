# Management Repo
* Installs components for IBM management repo service

## Introduction
Management Repo is a helm chart repository for storing and supplying IBM and local charts.

## Chart Details
This chart deploys a single instance of a helm repo pod on the master node of a Kubernetes environment. 

## Prerequisites
* Kubernetes 1.11.0 or later, with beta APIs enabled
* IBM core services including auth-idp service, MongoDB, and management-ingress
* Cluster Admin role for installation

### PodSecurityPolicy Requirements

This chart requires a PodSecurityPolicy to be bound to the target namespace prior to installation. Choose either a predefined [`ibm-anyuid-psp`](https://ibm.biz/cpkspec-psp) PodSecurityPolicy or have your cluster administrator create a custom PodSecurityPolicy for you:
* Custom PodSecurityPolicy definition:

```
apiVersion: extensions/v1beta1
kind: PodSecurityPolicy
metadata:
  name: icp-mgmt-repo-psp
spec:
  allowPrivilegeEscalation: true
  fsGroup:
    rule: RunAsAny
  requiredDropCapabilities:
  - MKNOD
  allowedCapabilities:
  - SETPCAP
  - AUDIT_WRITE
  - CHOWN
  - NET_RAW
  - DAC_OVERRIDE
  - FOWNER
  - FSETID
  - KILL
  - SETUID
  - SETGID
  - NET_BIND_SERVICE
  - SYS_CHROOT
  - SETFCAP
  runAsUser:
    rule: RunAsAny
  seLinux:
    rule: RunAsAny
  supplementalGroups:
    rule: RunAsAny
  volumes:
  - configMap
  - emptyDir
  - projected
  - secret
  - persistentVolumeClaim
  forbiddenSysctls:
  - '*'
```

### Red Hat OpenShift SecurityContextConstraints Requirements

This chart requires a SecurityContextConstraints to be bound to the target namespace prior to installation. To meet this requirement there may be cluster-scoped, as well as namespace-scoped, pre- and post-actions that need to occur.

The predefined SecurityContextConstraints [`ibm-anyuid-scc`](https://ibm.biz/cpkspec-scc) has been verified for this chart. If your target namespace is not bound to this SecurityContextConstraints resource you can bind it with the following command:

`oc adm policy add-scc-to-group ibm-anyuid-scc system:serviceaccounts:<namespace>` For example, for release into the `default` namespace:
``` 
oc adm policy add-scc-to-group ibm-anyuid-scc system:serviceaccounts:default
```

* Custom SecurityContextConstraints definition:

```
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: icp-mgmt-repo-scc
readOnlyRootFilesystem: false
allowedCapabilities: []
allowHostPorts: true
seLinuxContext:
  type: RunAsAny
supplementalGroups:
  type: MustRunAs
  ranges:
  - max: 65535
    min: 1
runAsUser:
  type: MustRunAsNonRoot
fsGroup:
  type: MustRunAs
  ranges:
  - max: 65535
    min: 1
volumes:
- configMap
- downwardAPI
- emptyDir
- persistentVolumeClaim
- projected
- secret
```

## Resources Required
* At least 640Mb of available memory
* At least 150m of available CPU
* At least a few GB of free storage

## Installing the Chart
_NOTE: Mgmt repo is intended to be installed by the Installer for internal chart management, not by a user_

Only one instance of mgmt repo should be installed on a cluster. 
To install the chart with the release name `mgmt-repo`:

```bash
$ helm install {chartname.tgz} -f {my-values.yaml} --namespace kube-system --name mgmt-repo --tls
```
- Replace `{chartname.tgz}` with the packaged mgmt-repo chart
- Replace `{my-values.yaml}` with the path to a YAML file that specifies the values that are to be used with the install command

The command deploys mgmt-repo on the Kubernetes cluster in the default configuration. The [configuration](#configuration) section lists the parameters that can be configured during installation.

### Verifying the Chart
Call the `/mgmt-repo/charts/index.yaml` endpoint to verify that mgmt-repo is functioning properly.

## Uninstalling the Chart

To uninstall/delete the deployment:

```console
$ helm delete mgmt-repo --purge --tls
```

The command removes all the Kubernetes components associated with the chart and deletes the release.

## Configuration

The following tables lists the configurable parameters of the mgmt repo chart and their default values.

Parameter                                       | Description                              | Default
----------------------------------------------- | ---------------------------------------- | -------
`apiVersion`|API version|extensions/v1beta1
`arch` |Node architecture to deploy to|amd64
`mgmtrepo.image.name`|management repo container image name|mgmt-repo
`mgmtrepo.image.repository`|management repo image path|hyc-cloud-private-integration-docker-local.artifactory.swg-devops.com/ibmcom//icp-helm-repo
`mgmtrepo.image.tag`|management repo image tag|latest
`mgmtrepo.image.pullPolicy`|management repo image pull policy|IfNotPresent
`mgmtrepo.env.CLUSTER_PORT`|management repo cluster port|8443
`mgmtrepo.env.CLUSTER_CA_DOMAIN`|management repo cluster domain|mycluster.icp
`mgmtrepo.env.PROXY_ROUTE`|management repo proxy route|mgmt-repo
`mgmtrepo.storage.capacity`|management repo storage capacity|5Gi
`mgmtrepo.storage.accessMode`|management repo storage access mode|ReadWriteOnce
`mgmtrepo.storage.hostPath`|management repo storage host path|/var/lib/icp/mgmtrepo
`mgmtrepo.resources.limits.cpu`|management repo cpu limits|100m
`mgmtrepo.resources.limits.memory`|management repo memory limits|256Mi
`mongo.host`|mongoDB host name|mongodb
`mongo.port`|mongoDB exposed port|27017
`mongo.username.secret`|mongoDB username secret|icp-mongodb-admin
`mongo.username.key`|mongoDB username key|user
`mongo.password.secret`|mongoDB password secret|icp-mongodb-admin
`mongo.password.key`|mongoDB password key|password
`mongo.clustercertssecret`|mongoDB cluster cert secret|cluster-ca-cert
`mongo.clientcertssecret`|mongoDB client cert secret|cluster-ca-cert
`auditService.name`|audit service container name|icp-audit-service
`auditService.image.repository`|audit service image path|hyc-cloud-private-integration-docker-local.artifactory.swg-devops.com/ibmcom//icp-audit-service
`auditService.image.tag`|audit service image tag|latest
`auditService.image.pullPolicy`|audit service image pull policy|IfNotPresent
`auditService.config.enabled`|audit service container enabled|true

## Storage
Chart packages and chart information is stored on volume mounts within the pod as well as with MongoDB.

## Limitations
Only one instance of Helm API should run at a single time, and should be restricted to running only on the master node.

## Documentation
Managing helm repositories:
https://www.ibm.com/support/knowledgecenter/SSBS6K_3.2.0/app_center/manage_helm_repo.html