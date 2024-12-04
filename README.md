# Artifactory local K3S installation for testing purpose
This sample project host a default values YAML files to configure a self-hosted artifactory instance with an external database and an external s3 bucket.
It is using a bucket provided by minio.
This has been tested using the kubernetes cluster provided by rancher desktop (v1.21+)

## Pre-requisites
Install [Minio](https://min.io/) as we will use it as S3 compatible filestore solution.
By default minio will runs on port 9000, but you can specify another one if you have a conflict, as in hte above command where we use port 9090

```
minio server --address :9090 /Users/johndoe/dev/minio-data
```
To access properly artifactory from outside Rancher K3S, install nginx-ingress controller in your cluster, with snippet annotations enabled :

```shell
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --set controller.allowSnippetAnnotations=true \
  --namespace ingress-nginx --create-namespace 
```

### Create the db and user

```SQL
CREATE USER jfrog WITH PASSWORD 'jfrog';
CREATE DATABASE artifactory WITH OWNER=jfrog ENCODING='UTF8';
CREATE DATABASE xray WITH OWNER=jfrog ENCODING='UTF8';
GRANT ALL PRIVILEGES ON DATABASE artifactory TO jfrog;
GRANT ALL PRIVILEGES ON DATABASE xray TO jfrog;
```
### Create a local S3 bucket using Min.io

- Start minio
- Using the webui, create a bucket named `rt-filestore`


## Jfrog platform helm chart installation

### First time install
Add licenses separated by newlines in a file named `art.lic`

Also update values in the `custom-values.yaml`.

Then run
```shell
helm upgrade --install jfrog-platform -f custom-values.yaml -f license-values-secret.yaml --namespace jfrog-platform --create-namespace jfrog/jfrog-platform
```

## Update to a new version 
Jfrog is not always releasing an updated Helm chart version for every version of artifactory (or other component), but you can update to a given version using the following command:

```
helm upgrade jfrog-platform --set global.versions.artifactory=7.84.16 --set databaseUpgradeReady=true --reuse-values --namespace jfrog-platform jfrog/jfrog-platform
```
:warning: **Always test any changes in your staging / dev env first !!**

Update the charts : 
```
helm repo update
```

## Reset everything

- Delete the jfrog/jfrog-platform namespace using `kubectl` or K9S
- Delete the filestore contents
```
aws s3 rm s3://my-filestore/artifactory/filestore --endpoint-url=http://localhost:4566 --recursive --profile localstack
```

### Drop and recreate the DB
```
DROP DATABASE artifactory;
CREATE DATABASE artifactory WITH OWNER=jfrog ENCODING='UTF8';
GRANT ALL PRIVILEGES ON DATABASE artifactory TO jfrog;
DROP DATABASE xray;
CREATE DATABASE xray WITH OWNER=jfrog ENCODING='UTF8';
GRANT ALL PRIVILEGES ON DATABASE xray TO jfrog;

```

OR

```
psql -U postgres -h localhost -f "reset-db.psql"
```

### Reinstall Artifactory

```shell
helm upgrade --install jfrog-platform -f custom-values.yaml -f license-values.yaml --namespace jfrog-platform --create-namespace jfrog/jfrog-platform
```

### Scale horizontally
```
helm upgrade jfrog-platform --set artifactory.artifactory.replicaCount=2 --reuse-values --namespace jfrog-platform jfrog/jfrog-platform
```
### Going beyond the basics 

### Bypassing ingress entry point 

Connect directly to artifactory svc on port 8082 using port forward
```
kubectl port-forward --namespace=jfrog-platform service/jfrog-platform-artifactory 8082:8082
```

#### Custom system.yaml
Many advanced configurations options rely on customizing Artifactory's `system.yaml` file.
What can be done is to pass the system.yaml file as a kubernetes secret (in this case it will takes precedence over equivalents settings in the values.yaml file).
If you need to apply configuration changes, then the best is to update the secret and perform a rolling restart 
```
  kubectl rollout restart sts jfrog-platform-artifactory --namespace=jfrog-platform
```

To create a secret for Xray system.yaml you can follow these steps
1. Locate the Xray pod using the following command:

```kubectl get pods -n xray```
 
2. Exec into the xray-server container of the Xray pod:
 
```kubectl exec -it <xray-podname> -c xray-server -n xray -- /bin/sh```

3. Output the system.yaml and copy the content:

```cat /opt/jfrog/xray/var/etc/system.yaml```

4. Create a new file on local machine for the system.yaml with the copied content and add the following parameters to update the open connections to the DB
```
server:
  database:
    #Default: 60
    maxOpenConnections: 90
analysis:
  database:
    #Default: 30
    maxOpenConnections: 60
indexer:
  database:
    #Default: 30
    maxOpenConnections: 60
persist:
  database:
    #Default: 30
    maxOpenConnections: 60
```
5. Create a kubernetes secret using the system.yaml file created on Xray namespace.

kubectl create secret generic sy --from-file ./xray-cus-sy.yaml -n xray

6. Update the custom values.yaml file for the system YAML override with the secret:

systemYamlOverride:
  existingSecret: sy
  dataKey: xray-cus-sy.yaml

7. Run a helm upgrade using the updated custom values.yaml from step 6. 
 
helm upgrade xray jfrog/xray -f cus-values.yaml -n xray

8. Once the kubernetes cluster has successfully deployed, to verify that the configurations have been updated as expected you may follow steps 1-3.

#### Custom storage classes
- For artifactory you can use `.artifactory.persistence.storageClassName`
- For Xray `xray.persistence.storageClass`
- For rabbitMQ `.rabbitmq.persistence.storageClass`
- The artifactory pvc is mounted at /var/opt/jfrog/artifactory
- usual sizing is that artifactory PVC size should be 15% of the expected filestore size
