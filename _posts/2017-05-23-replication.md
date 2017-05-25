---
layout: post
title: Database Replication, a bit of theory
meta: replication
draft: true
---

Let me start with some background. AlphaSights has offices in North America,
Europe and Asia and is rapidly expanding. People working in these 3 continents
rely heavily on the tools that we build to do their job, so any performance
issue has a big impact in their work. As the number of people using our systems
increased our database started to feel the pressure. Initially we could just
keep increasing our database server capacity, getting a more powerful machine,
adding more RAM, and keep scaling vertically, but there is one problem that we
cannot solve with more money, unfortunately: The speed of light.

No matter how quickly we can _execute_ a query, if the database is in North
America, the data still needs to travel all the way to Asia before people in
that office can use it. Our Asian colleagues think we can do better, and so do
we.

So the solution is to move this data closer to them, somewhere in Asia, so we
can save this travel time. Easy, right? Well...

#### Before we start

Before we start I just want to clarify a couple of things. I am by no means a
database/replication/Postgres expert, but in the process of researching what are
our options to solve the problem described above I learned a thing or two, and
that's what I want to share in this article. This is not supposed to be an
extensive resource to learn everything there is to know about replication, but
hopefully it's a good starting point that you can use in your own journey. In
the end of this article I will link to some great resources what will be helpful
if you decide to dig deeper.

Although most of the concepts explained here are pretty generic, some
things are specific to Postgres, as that is the database we use.

Sounds good? Cool.

#### First things first, the What and the Why

Just to make sure we are on the same page, let's define what replication is and
describe the three main reasons why we might want it.

When we say we want to replicate something, it means we want to keep a copy of
the same data in multiple places. In the case of databases, that can mean a copy
of the entire database, which is the most common scenario, or just some parts of
it (e.g. a set of tables). These multiple locations where we will keep the data
are usually connected by a network, and that's the origin of most of our
headaches, as you will see in a bit.

The reason for wanting that will be one of more of the following:

* You want to keep the data closer to your users so you can save the travel
time. Remember, no matter how fast your database is, the data still needs to
travel from the computer that started the request to the server where the
database is, and then back again. You can optimize the heck out of your
database, but you cannot optimize the laws of physics.

* You want to scale the number of machines serving requests. At some point a
single server will not be able to handle the number of clients it needs to
serve. In that case, having several databases with the same data helps you serve
more clients. That's what we call scaling _horizontally_ (as opposed to
_vertically_, which means having a more powerful machine).

* You want to be safe in case of failures (that will happen, don't fool
yourself). Imagine you have your data in single database server and that server
catches fire, then what happens? I am sure you have some sort of backup
(right?!), but your backup will a) take some time to be restored and b) probably
be _at least_ a couple of hours old. Not cool. Having a replica means you can
just start sending your requests to this server while you are solving the fire
situation, and it's likely that no one will even notice that something bad
happened.


#### And the obligatory CAP introduction


The CAP theorem was introduced by Eric Brewer in the year 2000, so it's not a
new idea. The acronym stands for `C`onsistency, `A`vailability and `P`artition
Tolerance, and it basically says that, given these 3 properties in a distributed
system, you need to choose 2 of them (i.e. you cannot have all 3). In practice,
it means you need to choose between consistency and availability when an
inevitable partition happens. If this sounds confusing, let me briefly define
what these 3 terms mean, and why I am even talking about this here.

<img src="/assets/images/replication/cap.png">

**Consistency**: In the CAP definition, consistency means that all the nodes in
a cluster (e.g. all your database servers, leaders and replicas) see the same
data at any given point in time. In practice, it means that if you query any of
your database servers at the exact same time, you will get the same result back.

> Notice that this is completely unrelated to the 'Consistency' from the
[ACID](https://en.wikipedia.org/wiki/Consistency_(database_systems)#As_an_ACID_guarantee)
> properties.


**Availability**: It means that reads and writes will always succeed, even if we
cannot guarantee that it will have the most recent data. In practice, it means
that we will still be able to use one of our databases, even when it cannot talk
to the others, and therefore might not have have received the latest updates.

**Partition Tolerance**: This means that your system will continue working even
if there is a network partition. In other words, if the nodes in your cluster
for some reason cannot talk to each other.

And why am I talking about this? Well, because depending on the route you take
you will have different trade-offs, sometimes favoring consistency and sometimes
availability.

How valuable the CAP theorem is in the distributed systems discussions is
debatable, but I think it is useful to keep in mind that you are almost always
trading consistency for availability (and vice-versa) when dealing with network
partitions.

#### A word about latency

_Latency_ is the time that a request is waiting to be handled (it's
_latent_). Our goal is to have the lowest latency possible. Of course, even with
a low latency we can still have a high _response time_ (if a query takes a long
time to run, for example), but that's a different problem. 

When we replicate our database we can decrease the latency by shortening the
distance this request needs to travel and/or increasing our capacity, so the
request doesn't need to wait before it can be handled due to a busy server.

I'm just mentioning this here because I think it's very important to be sure
that the reason why we are experiencing high response times is really because
the latency is high, otherwise we may be solving the wrong problem.

#### Asynchronous replication

When we talk about replication, we are basically saying that when I write some
data in a given node `A`, this same data also needs to be written in node `B`
(and maybe `C` and `D` and `E` and...), but we need to decide _how_ this
replication will happen, and what are the guarantees that we need. As always,
it's all about trade-offs. Let's explore our options.

The first option is to be happy to send a confirmation back to the client as soon
as the node that received the message has successfully written the data, and
_then_ send this message to the replicas (that may or may not be alive). It works
somewhat like this:

<img src="/assets/images/replication/async.png">

This looks great, we don't notice any performance impact as the replication
happens in the background, after we already got a response, and if the
replica is dead or slow we won't even notice it, as the data was already sent
back to the client. Life is good. You can feel that now is the time that I will
crush your dreams, can't you?

There are (at least) two main issues with asynchronous replication. The first is
that we are weakening our durability guarantees, and the other is that we are
exposed to replication lags. We will talk about the replication lag later, let's
focus on the durability issue first.

Our problem here is that if the node that received this write request fails
before it can replicate this change to the replicas, the data is lost, even
though we sent a confirmation to the client.

<img src="/assets/images/replication/async_failure.png">

You may be asking ourself

> "Jezz, but what are the chances of a failure happening right at THAT moment?!"

If that's the case, I'll suggest that you instead ask 

> "What are the _consequences_ if a failure happens at that moment?"

Yes, it may be totally fine to take the risk, but in the classic example of
dealing with financial transactions, maybe it's better to pay the price to have
stronger guarantees. But what is the price?

#### Synchronous replication

As you might expect, synchronous replication basically means that we will
_first_ replicate the data, and then send a confirmation to the client.

<img src="/assets/images/replication/sync.png">

So when the client gets the confirmation we can be sure that the data is
replicated and safe (well, it's never 100% safe, all of our data centers can, in
theory, explode at the same time, but it's safe enough).

The price we need to pay is: Performance and availability.

The performance penalty is due to the fact that we need to _wait_ for these -
potentially - slow replicas to do their thing and send us a confirmation before
we can tell the client that everything is going to be fine. As these replicas
are usually distributed geographically, and potentially very far from each
other, this takes more time than we would like to wait.

The second issue is availability. If one of the replicas (remember, we can have
many!) is down or we cannot reach it for some reason, we simply cannot write
any data. You should always plan for failures, and network partitions are more
common than we imagine, so depending on _all_ replicas being reachable to
perform any write doesn't seem like a great idea to me (but maybe it is for your
specific case).

#### Not 8, not 80

There's some middle ground. Some databases and replication tools allow us to
define a number of followers to replicate synchronously, and the others just use
the asynchronous approach. This is sometimes called _semi-synchronous replication_.

#### Single leader replication

The most common replication topology is to have a single leader, that then
replicate the changes to all the followers.

In this setup, the clients always send writes (in the case of databases,
`INSERT`, `UPDATE` and `DELETE` queries) to the leader, and never to a follower.
These followers can, however, answer read queries.

<img src="/assets/images/replication/single-leader.png">

The main benefit of having a single leader is that we avoid conflicts caused by
concurrent writes. All the clients are writing to the same server, so the
coordination is easier. If we instead allow clients to write to 2 different
servers at the same time, we need to somehow resolve the conflict that will
happen if they both try to change the same _object_, with different values (more
on that later).

So, what are the problem that we need to keep in mind if we decide to go with
the single leader approach? The first one is that we need to make sure that just
one node is able to handle all the writes. Although we can split the read work
across the entire cluster, all the writes are going to a single server, and if
you application is very write-intensive that might be a problem. Keep in mind
though, that most application read a lot more data than they write, so you need
to analyze if that's really a problem for you.

Another problem is that you will need to pay the latency price on writes.
Remember our colleagues in Asia? Well, when they want to update some data, that
query will still need to travel the globe before they get a response.

Lastly, although this is not really a problem just for single leader
replication, you need to think about what will happen when the leader node dies.
Is the entire system going to stop working? Will it be available just for reads
(from the replicas), but not for writes? Is there a process to _elect_ a new
leader (i.e.  promoting one of the replicas to a leader status)? Is this
election process automated or will it need someone to tell the system who is the
new king in town?

At first glance if seems like the best approach is to just have an automatic
failover strategy, that will elect a new leader and everything will keep working
wonderfully. That, unfortunately, is easier said than done.

##### The challenges of an automatic failover

Let me list _some_ of the challenges in implementing this automatic failover
strategy.

The first question we need to ask is: How can we be sure that the leader is
dead? And the answer is: We probably can't.  

There are a billion things that can go wrong, and, like in any distributed
system, it is impossible to distinguish a slow-to-answer from a dead node.
Databases usually use a timeout to decide that (e.g. if I don't hear from you in
20 seconds you are dead to me!). That is usually good enough, but certainly not
perfect. If you wait more, it is less likely that you will identify a node as
dead by mistake, but it will also take more time start your failover process,
and in the meantime your system is probably unusable. On the other hand, if you
don't give it enough time you might start a failover process that was not
necessary. So that is challenge number one.

Challenge number two: You need to decide who is the new leader. You have all
these followers, living in an anarchy, and they need to somehow agree on how
should be the new leader. For example, one relatively simple (at least
conceptually) approach it to have a predefined successor node, that will assume
the leader position when the original leader dies. Or you can choose the node
that has the most recent update (e.g. the one that is closer to the leader), to
minimize data loss. Any way you decide to choose the new leader, all the nodes
still need to _agree_ on that decision, and that's the hard part. This is known
as a [consensus
problem](https://en.wikipedia.org/wiki/Consensus_(computer_science)), and can be
quite tricky to get right.

Alright, you detected that the leader is really dead and selected a new leader,
now you need to somehow tell the clients to start sending writes to this new
leader, instead of the dead one. This is a _request routing_ problem, and we can
also approach it from several different angles. For example, you can allow
clients to send writes to any node, and have these nodes redirect this request
to the leader. Or you can have a _routing layer_ that receives this messages and
redirect them to the appropriate node.

If you are using asynchronous replication, the new leader might not have all the
data from the previous leader. In that case, if the old leader resurrects (maybe
it was just a network glitch) and the new leader received conflicting updates in
the meantime, how do we handle these conflicts?  
One common approach is to just discard these conflicts (using a last-write-win
approach), but that can also be dangerous (take this [Github
issue](https://github.com/blog/1261-github-availability-this-week) (from 2012)
as an example).

We can also have a funny (well, maybe it's not that funny when it happens in
production) situation where the previous leader comes back up and thinks it is
still the leader. That is called a _split brain_, and can lead to a weird
situation.

If both leaders starts accepting writes and we are not ready to handle conflicts
it is possible to lose data.

Some systems have fencing mechanisms that will force one node to shut down if it
detects that there are multiple leaders. This approach is known by the great
name `STONITH`, Shoot The Other Node In The Head.

> This is also what happens when there's a network partition and we end up with
> what appears to be two isolated clusters, each one with its own leader, as each
> part of this cluster cannot see the other, and therefore thinks they are all
> dead.

<img src="/assets/images/replication/split-brain.png">

As you can see, automatic failovers are not simple. There are a lot of things to
take into consideration, and for that reason sometimes it's better to have a
human manually perform this procedure. Of course, if your leader database dies
at 7pm and there's no one on-call, it might not be the best solution to wait
until tomorrow morning, so, as always, trade-offs.

#### Multi leader replication 

So, we talked a lot about single leader replication, now let's discuss an
alternative, and also explore its own challenges and try to identify scenarios
where it might make sense to use it.

The main reason to consider a multi leader approach is that is solves some of
the problems that we face when we have just one leader node. Namely, we have
more than one node handling writes, and these writes can be performed by databases
that are closer to the clients.

<img src="/assets/images/replication/multi-leader.png">

If your application needs to handle a very high number of writes, it might make
sense to split that work between multiple leaders. Also, if the latency price
to write in a database that is very far is too high, you could have one leader
in each location (for example, one in North America, one in Europe and another
in Asia).

Another good use case is when you need to support offline clients, that might be
writing to their own (leader) database, and these writes need to be synchronized
with the rest of the databases once this client gets online again.

The main problem you will face with multiple leaders accepting writes is
that you need some way to solve conflicts. For example, let's say you have a
database constraint to ensure that your users' emails are unique. If two
clients write to two different leaders that are not yet in sync, both writes
will succeed in their respective leaders, but we will have problems when we try
to replicate that data. Let's talk a bit more about these conflicts.

##### Dealing with conflicts

The easiest way to handle conflicts is to not have conflicts in the first place.
Not everyone is lucky enough to be able to do that, but let's see how that could
be achieved.

Let's use as an example an application to manage the projects in your company.
You can ensure that all the updates in the projects related to the American
office are sent to the leader in North America, and all the European projects
are written to the leader in Europe. This way you can avoid conflicts, as the
writes to the same projects will be sent to the same leader, while still using
the leader that is closer to the client.

Of course, this is a very biased example, and not every application can
"partition" its data in such an easy way, but it's something to keep in mind.

If that's not your case, we need another way to make sure we end up in a
consistent state. We cannot just let each node just apply the writes in the
order that they see them, because a node `A` may first receive an update setting
`foo=1` and then another update setting `foo=2`, while node `B` receive these
updates in the opposite order (remember, these messages are going through the
network and can arrive out of order), and if we just blindly apply them we would
end up with `foo=2` on node `A` and `foo=1` on node `B`. Not good.

One common solution is to attach some sort of timestamp to each write, and then
just apply the write with the highest value. This is called LWW (last write
wins). As we discussed previously, with this approach we may lose data, but
that's still very widely used.

> Just be aware that physical clocks [are not
> reliable](http://books.cs.luc.edu/distributedsystems/clocks.html), and when
> using timestamps you will probably need some sort to clock synchronization,
> like [NTP](https://en.wikipedia.org/wiki/Network_Time_Protocol).

Another solution is to record these conflicts, and then write application code
to allow the user to manually resolve them later. This may not be feasible in some
cases, like in our previous example with the unique constraint for the
email column. In other cases, though, it may be just a matter of showing two
values and letting the user decide which one should be kept and which should be
thrown away.

Lastly, some databases and replication tools allow us to write custom conflict
resolution code. This code can be executed on write or on read time.
For instance, when a conflict is detected a stored procedure can be called with
the conflicting values and it decides what to do with them. This is a _on write_
conflict resolution. [Bucardo](https://bucardo.org/wiki/Bucardo) and
[BDR](http://bdr-project.org/docs/stable/conflicts.html) are example of tools
that use this approach.

Other tools use a different approach, storing all the conflicting writes, and
also returning all of them when a client tries to read that value. The client is
then responsible for deciding what to do with those values, and write it back to
the database. [CouchDB](http://couchdb.apache.org/), for example, does that.

There is also a relatively new family of data structures that provide automatic
conflict resolution. They are called _Conflict-free replicated data type_, or
_CRDT_, and to still the
[wikipedia](https://en.wikipedia.org/wiki/Conflict-free_replicated_data_type)
definition:

> CRDT is a data structure which can be replicated across multiple computers in
> a network, where the replicas can be updated independently and concurrently
> without coordination between the replicas, and where it is always mathematically
> possible to resolve inconsistencies which might result.

Unfortunately there are some limitations to where these data structured can
be used (otherwise our lives would be too easy, right?), and as far as I know
they are still not very widely used for conflict resolution in databases,
although some CRDTs were implemented in [Riak](https://gist.github.com/russelldb/f92f44bdfb619e089a4d).

##### DDL replication

Handing DDLs (changes in the structure of the database, like adding/removing a
column) can also be tricky in a multi leader scenario. It's, in some sense, also
a conflict issue, we cannot change the database structure while other nodes are
still writing to the old structure, so we usually need to get a global database
lock, wait until all the pending replications take place, and then execute this
DDL. In the meantime, all the writes will either be blocked or fail. Of course,
the specific details will depend on the database or replication tool used, and
some of them will [not even
try](https://bucardo.org/wiki/Bucardo/FAQ#Can_Bucardo_replicate_DDL.3F) to
replicate DDLs, so you need to somehow do that manually, and other tools will
replicate _some_ types of DDLs, but not other (for instance, DDLs that need to
rewrite the entire table are forbidden in
[BDR](http://bdr-project.org/docs/1.0/ddl-replication-statements.html#DDL-REPLICATION-PROHIBITED-COMMANDS)).

The point is, there is a lot more coordination involved in replicating DDLs when
you have multiple leaders, so that's also something to keep in mind when
considering this setup.

##### The topologies of a multi leader setup

There are several different kinds of topologies that we can use with multiple
leaders. A topology defines the communication patterns between your nodes,
and different ways to arrange your communication paths have different
characteristics.

If you have only two leaders, there are not a lot of options: Node `A` sends
updates to node `B`, and node `B` sends updates to node `A`. Things start to get
more interesting when you have three or more leaders.

A common topology is to have each leader sending its updates to every other leader.

<img src="/assets/images/replication/all-to-all.png">

The main problem here is that messages can arrive out of order. For example, if
a node `A` inserts a row, and then node `B` updates this row, but node `C`
receives the update before the insert, we will have problems.

This is a _causaility problem_, we need to make sure that all the nodes first
process the insert event before processing the update event. There are different
ways to solve this problem (for instance, using [logical
clocks](https://en.wikipedia.org/wiki/Logical_clock)), but the point is: You
need to make sure your database or replication tool is actually handling this if
it's using this topology, or at least be aware that this is a failure that can
happen, in case it doesn't (like most do).

Another alternative is to use what some databases call the _start topology_.

<img src="/assets/images/replication/star.png">

In this case one node receives the updates and sends them to everyone else. With
this topology we can avoid the causality problem but, on the other hand,
introduce a single point of failure. If this central node dies, the replication
will stop. It's high price to pay, in some cases.

Of course, these are just 2 examples, but the imagination is the limit for all
the different topologies you can have, and there's no perfect answer, each one
will have their pros and cons.

#### And yes, leaderless replication

Another idea that was popularized  by Amazon's
[DynamoDB](https://aws.amazon.com/dynamodb/) (although it first appeared some
decades ago) is to simply have no leaders, every replica can accept writes
(maybe it should be called leaderful?).

It seems like this is going to be a mess, doesn't it? If we had lots of
conflicts to handle with a few leaders, imagine what will happen when writes are
taking place everywhere. Chaos!

Well, it turns out these database folks are not dumb, and there are some clever
ways to deal with this chaos.

The basic idea is that clients will send writes no only to one replica, but to
several (or, in some cases, to all of them).

<img src="/assets/images/replication/leaderless.png">

The client sends this write request concurrently to several replicas, and as
soon as it gets a confirmation from some of them (we will talk about how many
are "some" in a bit) it can consider that write a success and move on.

One advantage we have here is that we can tolerate node failures more easily.
Think about what would happen in a scenario where we had to send a write to a
single leader and for some reason that leader didn't respond. The write would
fail and we would need to start a failover process to elect a new leader that
could start receiving writes again. No leaders, no failover, and if you remember
what we've talked about failovers, you can probably see why this can be a big
deal.

But, again, there is no free lunch, so let's take a look at the price tag here.

What happens if, say, your write succeeds in 2 replicas, but fails in 1 (maybe
that server was being rebooted when you sent the write request)?  
You now have 2 replicas with the new value and 1 with the old value. Remember,
these replicas are not talking to each other, there's no leader handling any
kind of synchronization.

<img src="/assets/images/replication/leaderless-stale.png">

Now if you read from this replica, BOOM, you get stale data.

To deal with this problem, a client will not read data from one replica,
but also send requests to several replicas concurrently (like it did for
writes). The replicas then return their values, and also some kind of version
number, that the clients can use to decide which value it should use, and which
it should discard.

We still have a problem, though. One of the replicas still has the old value,
and we need to somehow synchronize it with the rest of the replicas (after all,
replication is the process of keeping the _same_ data in several places).

There are usually two ways to do that: We can make the client responsible for
this update, or we can have another process that is responsible just for finding
differences in the data and fixing them.

Making the client fix it is conceptually simple, when the client reads data from
several nodes and detects that one of them are stale, it sends a write request
with the correct value. This is usually called _read repair_.

The other approach, having a background process fixing the data, really depends
on the database implementation, and there are several ways to do that, depending
on how the data is stored. For example, `DynamoDB` uses an anti-entropy using
Merkle trees.

##### Quorums

So we said we need to send the write/read requests to "some" replicas. There are
good ways to define how many are enough, and what we are compromising (and
gaining) if we decide to decrease this number.

Let's first talk about the most obvious problematic scenario, when we require
just one successful response to consider a value written, and also read from
just one replica. From there we can expand the problem to more realistic
scenarios.

As there is no synchronization between these replicas, we will read stale values
every time we send a read request to a node other than the only one that
succeeded.

Now let's imagine we have 5 nodes and require a successful write in 2 of them,
and also read from 2. Well, we will have the exact same problem. If we write to
nodes `A` and `B` and read from nodes `C` and `D`, we will always get stale
data. 

What we need is some way to guarantee that at least one of nodes that we are
reading from is a node that received the write, and that's what quorums are.

For example, if we have 5 replicas and require that 3 of them accept the write,
and also read from 3, we can be sure that _at least_ one of these replicas that
we are reading from accepted the write and therefore has the most recent data.

Most databases allow us to configure how many replicas need to accept a write (`w`)
and how many we want to read from (`r`). A good rule of thumb is to always have
`w + r > number of replicas`.

Now you can start playing with these numbers. For example, if your application
writes to the database very rarely, but reads very frequently, maybe you can set
`w = number of replicas` and `n = 1`. What that means is that writes need to be
confirmed by every replica, but you can then read from just one of them as you
are sure every replica has the latest value. Of course, you are then making your
writes slower and less available, as just a single replica failure will prevent
any write from happening, so you need to measure your specific needs and what is
the right balance.

##### Quorums and majorities 

One thing 

#### Eventual Consistency

#### 2PC

#### Dealing with conflicts

#### The log

#### Adding new replicas

#### Logical and Physical replication

#### Sharding

#### PITR, or Point in Time Recovery

#### Streaming Replication

#### A word about backups

#### Delayed Replicas

#### Some tools

#### Working with third-party providers (namely Heroku and RDS)

#### Diving deeper

I hope this brief introduction to some of the theories and problems that we
need to be aware of when replicating a database made you curious to learn more.
If that's the case, here's the list of resources that I used (and am still
using) in my own studies and can blindly recommend:

Designing data intensive (chapter 5)
distributed systems for fun and profit (chapters 4 and 5)
Postgres replication (book)
Understanding Replication (paper)
The Dangers of Replication and a Solution (paper)

cap paper
cap critique paper
cap 12 years later


dynamo paper

- other things to mention: slit brain, quorums, tie breaker node
