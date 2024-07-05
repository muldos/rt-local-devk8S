# Artifactory local K8S installation for testing purpose
This sample project host a default values YAML files to configure a self-hosted artifactory instance with an external database and an external s3 bucket.
It is using a bucket provided by localstasck.

## Pre-requisites

### Create the db and user

```SQL
CREATE USER jfrog WITH PASSWORD 'jfrog';
CREATE DATABASE artifactory WITH OWNER=jfrog ENCODING='UTF8';
GRANT ALL PRIVILEGES ON DATABASE artifactory TO jfrog;
```
### Create a local S3 bucket and configure your AWS CLI 

- Start localstack `localstack start -d`
- Run aws configure to create a new profile

Once ok, create an S3 Bucket named 'my-filestore'

```shell
aws s3 mb s3://my-filestore --endpoint-url http://localhost:4566 --profile localstack
```

Check its content.

```shell
aws s3 ls --endpoint-url=http://localhost:4566 --recursive --human-readable --profile localstack
```

 :information_source: Note that this command could be used later on to validate that your setup is fine, once you've uploaded a file.

## Jfrog platform helm chart installation

### Firt time install
Update your license using the `yaml.tpl` provided, and rename it only to `.yaml`.

Also update values in the `custom-values.yaml`.

Then run
```shell
helm upgrade --install jfrog-platform -f custom-values.yaml -f license-values.yaml --namespace jfrog-platform --create-namespace jfrog/jfrog-platform
```

## Update to a new version 
Jfrog is not always releasing an updated Helm chart version for every version of artifactory (Or other componenents), but you can update to a given version using the following command:

```
helm upgrade jfrog-platform --set global.versions.artifactory=7.84.16 --set databaseUpgradeReady=true --reuse-values --namespace jfrog-platform jfrog/jfrog-platform
```
:warning: **Always test any changes in your staging / dev env first !!**


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
```
### Reinstall Artifactory

```shell
helm upgrade --install jfrog-platform -f custom-values.yaml -f license-values.yaml --namespace jfrog-platform --create-namespace jfrog/jfrog-platform
```
