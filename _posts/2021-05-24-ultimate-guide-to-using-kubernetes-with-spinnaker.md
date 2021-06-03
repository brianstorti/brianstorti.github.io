---
layout: post
title: Ultimate Guide to Using Kubernetes with Spinnaker
meta: Ultimate Guide to Using Kubernetes with Spinnaker
draft: true
---

## Introduction

Spinnaker is an open-source continuous delivery platform created by Netflix to enable engineers to release software changes seemingly. It works natively with several different orchestration tools and cloud providers.

In this article you will setup a new Spinnaker cluster and build a delivery pipeline, having code changes being automatically deployed to your Kubernetes cluster.

![Deployment Workflow](https://imgur.com/wlayCHc.png)

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

# spin-clouddriver-648796f8d8-d8rfs   0/1     ContainerCreating   0          12s
# spin-deck-77444987dd-r4fkl          0/1     ContainerCreating   0          12s
# spin-echo-f6d78ddd5-f5m6p           0/1     ContainerCreating   0          12s
# spin-front50-5d9c9fbd65-gpqt8       0/1     ContainerCreating   0          12s
# spin-gate-76db474459-f6wf5          0/1     ContainerCreating   0          12s
# spin-igor-555cd9745b-xzrwr          0/1     ContainerCreating   0          12s
# spin-orca-6648cb9875-nvzs9          0/1     ContainerCreating   0          12s
# spin-redis-6f84989bfd-rdpmn         0/1     ContainerCreating   0          12s
# spin-rosco-7c468bc6dc-nnpwh         0/1     ContainerCreating   0          12s
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

![Spinnaker home page](https://imgur.com/0056pMR.png)

## Deploying Your First Service With Spinnaker

To get a taste of Spinnaker, you will create your first pipeline, deploying a simple `nginx` container.

In the Spinnaker home page, click the `Create Application` button and set a name and the owner email.

![Spinnaker new application popup](https://imgur.com/6HSlcPL.png)

On the left side, click on the `Pipelines` menu, and then `Configure a new pipeline`.

![Spinnaker pipeline view](https://imgur.com/k5PC2SK.png)

Give this pipeline a name, like `Deploy Nginx` and click `Create`.

You will be taken to the pipeline configuration page. Every pipeline is composed of a configuration and one or more _stages_ and each stage can have a different _type_.

For this example, you don't need to change any configuration, so just create a new stage by clicking the `Add stage` button.

In the new stage page, you will select the type `Deploy (Manifest)`, which is used to deploy Kubernetes manifests, and the account `demo-account`, that is where this manifest will be applied. If you had multiple clusters, like one of Staging and another for Production, each one would be a different `account`, and this setting is what would tell Spinnaker in which cluster that stage should run.

![Pipeline stage to deploy manifest](https://imgur.com/5crr6gT.png)

In the `Manifest Configuration` section of this same page is where we can define where the manifest will come from. We can either have the manifest text hard-coded in the page, or choose an artifact, which means an object that references an external source, like, for instance, a github file.

To keep things simple for now, you can select `text` and paste a manifest directly in the Spinnaker UI. Here's a simple manifest defining a Kubernetes service and a deployment for `nginx`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-svc
  namespace: default
spec:
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80

---

apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - image: nginx
        name: nginx-container
```

![Manifest yaml in Spinnaker](https://imgur.com/dO7X1BK.png)

You can now save these changes and go back to the Pipelines page, where you will see the pipeline you just created. On the right side of this pipeline you can `Start Manual Execution` to manually trigger the pipeline.

![Pipeline executing in Spinnaker](https://imgur.com/4Im3AiK.png)

After it finishes running, you can confirm with `kubectl` that a new service and pod were created:

```
$ kubectl get pod,svc

NAME                         READY   STATUS    RESTARTS   AGE
pod/nginx-7bc7d78944-cm7qs   1/1     Running   0          90s

NAME                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/nginx-svc    ClusterIP   10.104.56.154   <none>        80/TCP    91s
```

And you can also use `kubectl port-forward` to access `nginx` from your browser on port `8080`:

```
$ kubectl port-forward service/nginx-svc 8080:80
```

And that's it, your first service deployed to Kubernetes through Spinnaker!

## Understanding Spinnaker

Before you move ahead, it's important to understand a few terms used by Spinnaker, as it creates some abstractions to work with several different providers and it doesn't always map 1-to-1 with the terminology used in Kubernetes.

There are four main pages that you'll see for your applications:

* **Pipelines**: It's the page you just used to deploy an application. In this page you can create as many pipelines as you want, each one composed of one or more _stages_. For example, you could have two pipelines to deploy your application, one for production and another for staging. In each of these pipelines, you could have a stage to apply a `ConfigMap` with your application's configuration, another stage to run a `Job` that applies your database migrations and a final stage to apply your `Deployment`. Spinnaker provides the building blocks you can use to build the delivery pipeline the way you want.

* **Clusters**: This is where you will see your workloads. In this example, you will see the `nginx` `Deployment` with `ReplicaSet` `v001` and all the `Pods` that are being managed by this `ReplicaSet`.

![Spinnaker clusters view](https://imgur.com/6eoEgLx.png)

* **Load Balancers**: This is where Spinnaker shows our Kubernetes `Service`s and `Ingress`es. You can see you have a single service, `nginx-svc`, and all the pods that behind it.

![Spinnaker load balancers view](https://imgur.com/sZHiNzv.png)

* **Firewalls**: Lastly, we have the `Firewalls`, where Spinnaker shows our `NetworkPolicies`. You haven't create any policies, so this page should be empty. 

It's important to note these terms could mean very different things for different providers. For example, if you were using AWS, you could use Spinnaker to spin up a new Application Load Balancer (ALB).

## Building Your Own Service

Now that you have a better understanding of Spinnaker and how it interacts with Kubernetes, you can create your own service and an entire delivery pipeline end-to-end. The goal is to push a code change to Github and see that change deployed to your Kubernetes cluster, following the steps you define.

#### Creating a simple example service

For this example, I will use a very simple `Ruby` service that just returns the message "Hello, Spinnaker!". Here's the entire code for it:

```ruby
# app.rb
require "sinatra"
set :bind, "0.0.0.0"

get "/" do
  "Hello, Spinnaker!"
end
```

And its `Dockerfile`:

```Dockerfile
# Dockerfile
FROM ruby:2.7
RUN gem install sinatra
COPY app.rb /
CMD ["ruby", "app.rb"]
```

And to test the service is working as expected locally:

```
$ docker build . -t sample-app

$ docker run -p 4567:4567 sample-app

$ curl http://localhost:4567
# Hello, Spinnaker!
```

There you go, you have a simple Dockerized service that's ready to be used for your delivery pipeline!

Now you can push this code to a Github project, like I did [here](https://github.com/brianstorti/sample-app-for-spinnaker).

#### Creating a Dockerhub Project

The next step is to create a repository on Dockerhub. That's where your Docker images will live. You will use Dockerhub to build new images when you push a tag to Github, and that will later trigger a Spinnaker pipeline to deploy this new image.

In your Dockerhub account, create a new repository linked to the Github project that has the code for your sample service and create a build rule to build a new Docker image every time a tag is pushed:

![Dockerhub new repository page](https://imgur.com/LiZbsvF.png)

We are using Dockerhub in this example, but there are various other tools you can use to build and store your Docker images. You could, for example, use Jenkins to build an image after your automated tests pass, and push that image to a private repository on Amazon `ECR`.

To make sure everything is working as expected, you can push a new git tag to Github and watch Dockerhub building a Docker image:

```
$ git tag 1.1 && git push --tags
```

![Dockerhub building new image](https://imgur.com/WqU2mcH.png)

#### Creating Kubernetes Manifests For Your Service

Lastly, you will create a Kubernetes `Service` and `Deployment` for this service and push to the same Github repository:

```yaml
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: sample-app-svc
  namespace: default
spec:
  selector:
    app: sample-app
  ports:
  - port: 80
    targetPort: 4567
```

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sample-app
  template:
    metadata:
      labels:
        app: sample-app
    spec:
      containers:
      - image: index.docker.io/brianstorti/sample-app-for-spinnaker # CHANGE YOUR ACCOUNT
        name: sample-app
```

Make sure you change the image in the deployment to it uses your account and repository names. Also note that this deployment is not specifying any specific image tag. That's because you want to let Spinnaker _bind_ the image tag that's received when a pipeline is triggered by Dockerhub.

## Building a Continuous Delivery Pipeline For Your Service

Now that you have Spinnaker up and running and a service on Github that you can push changes to and have new Docker images created by Dockerhub, you are ready to put all the pieces together and create a delivery pipeline that will be triggered when something changes.

#### Configuring `halyard` For Github and Dockerhub

The first step is to enable Github as an artifact provider, so Spinnaker can fetch the manifest files, and the Dockerhub provider, so it can trigger a pipeline when new images are built.

For Github, you'll need to [have a token](https://github.com/settings/tokens) (with the `repo` scope if you want to use a private repository).

In your `halyard` container, first enable the Github artifact source:

```
$ echo "your github token" > github-token
$ hal config artifact github account add my-github-account --token-file github-token
$ hal config artifact github enable
```

And then enable the Dockerhub provider, changing the `--repositories` value to use your own account name and repository name:

```
$ hal config provider docker-registry enable
$ hal config provider docker-registry account add my-docker-registry \
  --address index.docker.io \
  --repositories brianstorti/sample-app-for-spinnaker
```

And that's it, Spinnaker can now interact with Github and Dockerhub.

#### Creating a New Spinnaker Pipeline For Your Service

Now that you have all the integrations in place, you are ready to put in place a fully automated delivery pipeline for this simple service.

You will start by creating a new application in Spinnaker, like you did for the `nginx` example. I will call it `my-service`.

![New application for your service](https://imgur.com/LcY9MRt.png)

In the application's Pipeline page, you will create a new pipeline that will be responsible for deploying this service. I will call it `Deploy service`.

In this pipeline configuration you can set up a new _Automated Trigger_. These are things can trigger the pipeline automatically, like a webhook call, a cron schedule or, in this case, a new image being pushed to Dockerhub. Go ahead and select `Docker Registry` as the automated trigger type. For the `Registry Name` you will see the provider you set up previously, `my-docker-registry`, in the `Organization` field you will see your username (or organization) and for the `Image` you see the repository you configured:

![Spinnaker automated trigger](https://imgur.com/E3j0hSK.png)

Notice the `Tag` field was left empty, which means any image tag will be trigger this pipeline. You could also define an specific pattern for image tags to be deployed. For example, you could have `production-*` and `staging-*` tags triggering different pipelines.

If you now save and try to manually run this pipeline, you will be prompted for the image tag you want to trigger the pipeline with.

![Manual pipeline execution popup](https://imgur.com/SZ7zXuI.png)

This indicates the trigger is working as expected.

#### Fetching Manifests From Github

You could define your Kubernetes `yaml` manifests directly in Spinnaker, like you did previously for `nginx`, and that works fine, but we lose the benefits of having these manifests versioned with our code, and potentially even making changes to these files in Github trigger a pipeline execution.

For this sample service, you will make Spinnaker fetch the files directly from the Github repository you created previously. This repo has two manifest files: `service.yaml` and `deployment.yaml`, so you will create two stages in this pipeline you just configured, one to deploy the service, and another to create the Kubernetes `service`.

Go ahead and create a new stage in this pipeline with the type `Deploy (Manifest)` and name `Apply Deployment`. Select the `demo-account` and in the Manifest Configuration section select `artifact` instead of `text`.

For the Manifest Artifact field you will choose `Define a new artifact` and then select the Github account you configured. For the Content URL, you will define the api URL that Spinnaker will use to fetch this file from Github, following this pattern:

```
https://api.github.com/repos/<YOUR-USERNAME>/<YOUR-REPO>/contents/<FILE-PATH>
```

For example, to get the file from my repository, I'm using this path:

```
https://api.github.com/repos/brianstorti/sample-app-for-spinnaker/contents/deployment.yaml
```

And, lastly, the commit or branch to be used, which will be `main` by default on Github.

![Pipeline stage to apply deployment](https://imgur.com/RSTE6oA.png)

You can now follow the same process, creating a new stage to deploy your `service.yaml` manifest from Github, and the end result should be this:

![Pipeline stage to apply service](https://imgur.com/dR7nDo7.png)

And that's it! Every time you push a tag to Github, a new Docker image will be built, that will automatically trigger your Spinnaker pipeline that will fetch the your manifest files from Github, _bind_ the docker image to this manifest updating the image to be deployed, and apply these manifests to your Kubernetes cluster.

#### Seeing It in Action

To see this entire process in place, you can push a new tag to your Github repository and watch the pipeline runs until your change is live.

First, in your service's repository change the `app.rb` file, adding a `(v2)` to the returned string:


```ruby
get "/" do
  "(v2) Hello, Spinnaker!"
end
```

And now commit, tag and push the changes to Github:

```
$ git commit -am "Changes for v2" && git tag 2.0
$ git push && git push --tags
```

These are the actions you need to take, now you can just watch the delivery pipeline in action.

First, Dockerhub will notice this new `2.0` tag in Github and start building a new image tagged `release-2.0`.

![Dockerhub building release-2.0](https://imgur.com/onr760L.png)

Then, after the build is done, Spinnaker will notice the new Docker image present in your registry, and that will trigger a pipeline execution:

![Pipeline automatically trigged in Spinnaker](https://imgur.com/E0Vbkda.png)

After Spinnaker finishes running, you can see the newly deployed resources in your cluster:

```
$ kubectl get deploy,service
AME                         READY   UP-TO-DATE   AVAILABLE
deployment.apps/sample-app   1/1     1            1

NAME                     TYPE        CLUSTER-IP
service/sample-app-svc   ClusterIP   10.106.238.227
```

To see the service running and make sure your changes are there, you can again use `port-forward`:

```
$ kubectl port-forward service/sample-app-svc 8080:80

# in another terminal session
$ curl http://localhost:8080
(v2) Hello, Spinnaker!
```

#### Dealing With a Bad Release

Spinnaker also makes it easier to deal with a bad release, giving you an interface to see the pods status, explore logs and potentially rollback to a previous version.

To see how that works, you can push a code change that introduces an error:

```ruby
# app.rb
get "/" do
  raise "Whoops, something went wrong"
end
```

```
$ git commit -am "Introduce error" && git tag 2.1
$ git push && git push --tags
```

The same as before, you will see Dockerhub building a new `release-2.1` image and Spinnaker deploying it, except this time when you try to send a request to this service it will fail:

```
$ curl http://localhost:8080/
RuntimeError: Whoops, something went wrong
        app.rb:6:in `block in <main>'
        /usr/local/bundle/gems/sinatra-2.1.0/lib/sinatra/base.rb:1675:in `call'
        /usr/local/bundle/gems/sinatra-2.1.0/lib/sinatra/base.rb:1675:in `block in compile!'
        /usr/local/bundle/gems/sinatra-2.1.0/lib/sinatra/base.rb:1013:in `block (3 levels) in route!'
        /usr/local/bundle/gems/sinatra-2.1.0/lib/sinatra/base.rb:1032:in `route_eval'
        /usr/local/bundle/gems/sinatra-2.1.0/lib/sinatra/base.rb:1013:in `block (2 levels) in route!'
        /usr/local/bundle/gems/sinatra-2.1.0/lib/sinatra/base.rb:1061:in `block in process_route'
        /usr/local/bundle/gems/sinatra-2.1.0/lib/sinatra/base.rb:1059:in `catch'
        ...
```

When you access Spinnaker's `Clusters` page, you will see you have 2 releases for this deployment, `v001` and `v002`, just `v002` having active pods, represented by the green square.

![Spinnaker clusters view for your application](https://imgur.com/HQV3jOQ.png)

Clicking on this green square, you will be a lot of information about the pod, and also a link to access the `Console Output`, where you can see the logs this pod is generating with the error message that should help you identify the problem.

![Console logs in the Spinnaker UI](https://imgur.com/9nlSDEi.png)

After having decided the best course of action is to rollback this release, you can click on the box representing the Kubernetes deployment, where you will see the `Deployment Actions` that can be performed. Choose `Undo Rollout` and select the previous versions, `v001`.

![Dropdown to undo rollout in Spinnaker](https://imgur.com/vKnHgCv.png)

After a few seconds the previous version will be live again and the service is back up:

```
$ curl http://localhost:8080
(v2) Hello, Spinnaker!
```

In this `Deployment Actions` section you can also scale deployments up and down by changing the number of replicas that are running, directly edit the deployment's `yaml` definition or destroy it entirely.

## Conclusion

In this article, you have configured a new Spinnaker cluster, as well as its integration with several other services, like Github and Dockerhub, making it ready to deploy changes to your Kubernetes cluster. You have also built a delivery pipeline that continuously releases changes pushed to Github.

Spinnaker is a very mature platform and there are a lot of features that were not covered here. To know more about what Spinnaker can do, check the [official website](https://spinnaker.io/).

If you are running your applications or even Spinnaker itself on Kubernetes, checkout how [ContainIQ](https://www.containiq.com/) can help you monitor your cluster's events and metrics and give you actionable insights to improve its health and performance.
