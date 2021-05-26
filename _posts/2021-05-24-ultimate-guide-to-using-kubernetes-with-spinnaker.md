---
layout: post
title: Ultimate Guide to Using Kubernetes with Spinnaker
meta: Ultimate Guide to Using Kubernetes with Spinnaker
draft: false
---

## Introduction

## Prerequisites

To follow along, you will need:

* A Kubernetes 1.16+ cluster. I'm running a local Kubernetes cluster using `Docker for Mac`, but you are free to create a cluster using another method or use a managed cluster from a cloud provider.
* The `kubectl` command-line tool installed and configured to connect to your cluster.

## Running Spinnaker

Spinnaker is composed of several services that run independently, and running each one of them manually would be a lot of work. Thankfully, the Spinnaker team also provides a CLI tool, called `halyard`, to help installing, configuring, and upgrading Spinnaker.

Using `halyard`, we will run all these services that compose Spinnaker in our Kubernetes cluster. In this article I will run Spinnaker in the same Kubernetes cluster as my applications, but you could also have a dedicated cluster just for Spinnaker.

#### Running Halyard

The first thing you need to do is to run `halyard`:

```
$ docker run --name halyard --rm -it \
    -v ~/.hal:/home/spinnaker/.hal \
    -v ~/.kube:/home/spinnaker/.kube \
    us-docker.pkg.dev/spinnaker-community/docker/halyard:stable
```

Here you are running a container named `halyard`, using the stable image provided by the Spinnaker team, and mounting 2 volumes: One for the directory where `halyard` stores its configuration, `~/.hal`, and another for your `.kube` directory, because Spinnaker will need to access your `kubeconfig` file.

After the `halyard` daemon is running and you starting seeing its logs, in another terminal window you can run this command to get a bash session in this container:

```
$ docker exec -it halyard bash
```

And you can make sure `halyard` is running fine running:

```
$ hal --version
# 1.42.1-20210517175407
```

#### Configuring a Spinnaker Provider

In Spinnaker, you need to enable the providers you want to use. These providers are integrations to cloud platforms where you can deploy your applications. For example, you can register `AWS` and `GCE` as providers you want to have.

In this case, you will run both Spinnaker and your applications in Kubernetes, and Spinnaker has a native Kubernetes provider, so that's the only thing you will need to enable:

```
$ hal config provider kubernetes enable
```

And then you need to add an account to this provider, that's how Spinnaker will know how to access it. As you are using the Kubernetes provider, the only thing you need is to give this account a name and tell Spinnaker which context from your `kubeconfig` should be used.

Here I'm defining a `demo-account` account, saying it should use my `demo-cluster` context:

```
$ hal config provider kubernetes account add demo-account \
  --context demo-cluster
```

If you were using multiple cluster, like one for Production and another for Spinnaker, you could add two accounts here, just setting the right context from your `kubeconfig` for each one.

Now that you have your account defined and ready to be used, you can tell halyard that is where our Spinnaker microservices should be deployed to:

```
$ hal config deploy edit \
    --type distributed \
    --account-name demo-account
```

The `--type distributed` flag is what tells Spinnaker to run its services in Kubernetes, and it's the recommended environment for production deployments. Alternatively, you can also use the type `localdebian`, which will install all the services on a single machine, where halyard is running.

The `--acount-name demo-account` flag is saying halyard should use the `demo-account` you just configured to deploy Spinnaker. It's here that you could set a different account if you were using separate clusters for your apps and Spinnaker.

#### Configuring External Storage for Spinnaker

When you change your application's setting and pipelines, Spinnaker persists that in an external storage. Several providers are supported out of the box, like Amazon S3, Google Cloud Storage and Azure Storage. You can see the updated list of supported storage solutions in the [Spinnaker docs](https://spinnaker.io/setup/install/storage/#supported-storage-solutions).

In this example I'll use Amazon S3.

First, you need to set the storage type to `s3`:

```
$ hal config storage edit --type s3
```

And then configure this storage with your s3 credentials:

```
$ hal config storage s3 edit \
    --access-key-id $YOUR_ACCESS_KEY_ID \
    --secret-access-key
```

Here you're providing your aws access key id, and halyard will prompt for your secret access key.

After this is done, you're ready to deploy Spinnaker.

#### Deploying Spinnaker

With all the configuration in place, you can now finally deploy Spinnaker!

Still using the halyard container, you'll set the Spinnaker version you want to use and then apply these configs:


```
$ hal config version edit --version 1.25.4
$ hal deploy apply
```

When you run `hal deploy apply`, halyard will check everything is fine and will start running the Spinnaker services in the account we configured.  

Assuming you have `kubectl` running and using the same context you used for Spinnaker (`demo-cluster`), you can see the pods being created in the `spinnaker` namespace:

```
$ kubectl get pods --namespace spinnaker
# TODO add output here
```

#### Accessing Spinnaker locally

After all this work, now it's time for a reward: Seeing Spinnaker running!

In your host machine (not in the `halyard` container), you'll use `kubectl` again to expose two Spinnaker services, `deck` and `gate`.

`deck` is the actual UI you will access in your browser, and `gate` is the API gateway that the UI uses to communicate with all the other services.

Now go ahead and use `kubectl` to expose these services (you will need to run each command in a separate window):

```
$ kubectl -n spinnaker port-forward service/spin-gate 8084
$ kubectl -n spinnaker port-forward service/spin-deck 9000
```

And that's it, you'll be able to access Spinnaker locally on `http://localhost:9000`.

```
echo "my github token" > github-token # token with repo access
hal config artifact github account add my-github-account --token-file github-token

hal config provider docker-registry enable
hal config provider docker-registry account add my-docker-registry \
  --address index.docker.io \
  --repositories brianstorti/sample-app-for-spinnaker
```

## Deploying Our First Service With Spinnaker

## Building a Delivery Pipeline For Our Own Service

## Conclusion
