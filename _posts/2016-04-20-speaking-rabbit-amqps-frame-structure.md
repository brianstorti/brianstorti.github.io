---
layout: post
title: Speaking Rabbit&#58; A look into AMQP's frame structure
meta: Speaking Rabbit&#58; A look into AMQP's frame structure
draft: true
---

`RabbitMQ` supports several different messaging protocols, but there is no doubt that `AMQP` (0-9-1) is the what is most commonly used (and what `RabbitMQ`
was originally developed for).  
It's `AMQP` that defines how exchanges, queues, binding and most of the things that you, as an application developer, usually have to work with.

`AMQP` is conceptually divided in two layers, the functional and the transport. Here I want to talk about an important part of the transport layer: Framing.

A frame is `AMQP`'s basic unit. They are the chunks of data that are used to send information from `RabbitMQ` to your application and vice-versa. Let's first take a look
at what a frame looks like and what are all the different types of frames that can be used.

#### The anatomy of a frame

There are 5 types of frames defined in the `AMQP` specification, they are:

* **Protocol header**: This is the frame sent to establish a new connection between the broker (`RabbitMQ`) and your application.

* **Method frame**: Carries a RPC request or response. For example, when we are publishing a message, we first send a `Basic.Publish` frame that tells
`RabbitMQ` that a client is going to publish a message.

* **Content header**: Certain specific methods carry a content (like `Basic.Publish`, for instance), and the content header frame is used to send the properties
of this content. For example, this frame may have the content-type of a message that is going to be published or a timestamp.

* **Body**: This is the frame with the actual content of your message, and can be split in multiple different frames if the message is too big (131KB is the default frame size limit).

* **Heartbeat**: Used to confirm that a given client is still alive.

Every frame will have the same basic structure:

<img src="/assets/images/frame.png">

The payload will be interpreted in a different way accordingly with the frame type (that is one of the 5 described above).

#### Publishing and consuming messages

When publishing a message, the client application needs to send at least 3 frames: The method (`Basic.Publish`), the content header, and one or more body
frames, depending on the size of the message:

<img src="/assets/images/sequence.png">

And consuming messages is pretty much the same thing, but it's the broker, `RabbitMQ`, that sends the frames to our client application:

<img src="/assets/images/sequence-deliver.png">

#### Diving deeper

This was a very short overview of the way `RabbitMQ` sends data over the wire. You will not normally need to deal directly with `RabbitMQ`'s frames, unless you are
building a client library, but that's the foundation of every kind of communication that happens between your application and the broker, so getting a bit more familiar 
with how things work under the hood doesn't hurt. Also, the next time you see a `unexpected_frame` error in your logs you will have a clue of what is going on.

To get more information about how `AMQP` works, the [specification](https://www.rabbitmq.com/resources/specs/amqp0-9-1.pdf) is quite readable and not that long.  
For a more `RabbitMQ`-specific approach, [RabbitMQ in Depth](https://www.manning.com/books/rabbitmq-in-depth) is also a great resource.
