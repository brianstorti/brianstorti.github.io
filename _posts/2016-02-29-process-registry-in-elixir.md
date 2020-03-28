---
layout: post
title: Process registry in Elixir&#58; a practical example
meta: Process registry in Elixir
draft: false
---

Processes in `Elixir` (and `Erlang`, for that matter) are identified with a unique process id, the `pid`.  
That's what we use to interact with them. We send a message to a `pid` and the VM takes care of delivering it to the
correct process. Sometimes, though, relying on the `pid` of a process can be problematic.  

Let's create a simple application to see what issues we can have and what are some ways to solve them.

#### Starting with no registry at all

For this example we will create a simple chat application. Let's go ahead and create a new `mix` project for it:

```bash
$ mix new chat
```

And we can create a pretty standard `GenServer` that will be used throughout these examples:

```elixir
# in lib/chat/server.ex

defmodule Chat.Server do
  use GenServer

  # API

  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

  def add_message(pid, message) do
    GenServer.cast(pid, {:add_message, message})
  end

  def get_messages(pid) do
    GenServer.call(pid, :get_messages)
  end

  # SERVER

  def init(messages) do
    {:ok, messages}
  end

  def handle_cast({:add_message, new_message}, messages) do
    {:noreply, [new_message | messages]}
  end

  def handle_call(:get_messages, _from, messages) do
    {:reply, messages, messages}
  end
end
```

> If this still does not look familiar to you, `Elixir`'s  getting started
guides has a [great introduction](http://elixir-lang.org/getting-started/mix-otp/genserver.html) to `OTP`
that is worth checking.

And we can now start an `iex` session to test this server:

```elixir
$ iex -S mix

iex> {:ok, pid} = Chat.Server.start_link
{:ok, #PID<0.107.0>}

iex> Chat.Server.add_message(pid, "foo")
:ok

iex> Chat.Server.add_message(pid, "bar")
:ok

iex> Chat.Server.get_messages(pid)
["bar", "foo"]
```

So far so good. We get a `pid` when we start this process, and then for every message we want to 
send (`add_message/2` and `get_messages/1`) we pass this `pid` and everything works as expected.

Things start to get more interesting when we introduce a `Supervisor`.


#### Introducing a Supervisor

If for some reason our `Chat.Server` process dies, we are left there, sad and alone in our `iex` session, without any choice other
than manually starting a new process and sending messages to this new `pid`. Let's create a `Supervisor` so we don't need to worry about that.

```elixir
# in lib/chat/supervisor.ex

defmodule Chat.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do
    children = [
      worker(Chat.Server, [])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
```

Creating a `Supervisor` is simple enough, but now we have a problem if we try to follow the same approach we did before. We are not 
starting the `Chat.Server` process ourselves, the `Supervisor` is taking care of that and we just don't have access to the `pid` of
the processes that the `Supervisor` creates.  

This is a property of the `Supervisor` pattern. You can't have access to its children's `pid` as it will,
when necessary, restart these processes (which actually means it will kill and start a new process, with a different `pid`).


#### Registering a process name

To access our `Chat.Server` process we need some way to reference it using something other than the `pid`, a reference that
will be the same even if the process is restarted by the `Supervisor`. We need to give it a name.  

So let's change `Chat.Server`:

```elixir
# lib/chat/server.ex

defmodule Chat.Server do
  use GenServer

  def start_link do
    # We now start the GenServer with a `name` option.
    GenServer.start_link(__MODULE__, [], name: :chat_room)
  end

  # And our function don't need to receive the pid anymore,
  # as we can reference the process with its unique name.
  def add_message(message) do
    GenServer.cast(:chat_room, {:add_message, message})
  end

  def get_messages do
    GenServer.call(:chat_room, :get_messages)
  end

  # ...
end
```

And it should continue working the same way, except we don't need to pass the `pid` around anymore:

```elixir
$ iex -S mix

iex> Chat.Supervisor.start_link
{:ok, #PID<0.94.0>}

iex> Chat.Server.add_message("foo")
:ok

iex> Chat.Server.add_message("bar")
:ok

iex> Chat.Server.get_messages
["bar", "foo"]
```

And if the process is restarted we should be able to access it in the same way:

```elixir
iex> Process.whereis(:chat_room)
#PID<0.111.0>

iex> Process.whereis(:chat_room) |> Process.exit(:kill)
true

iex> Process.whereis(:chat_room)
#PID<0.114.0>

iex> Chat.Server.add_message "foo"
:ok

iex> Chat.Server.get_messages
["foo"]
```

That will do the job for our current scenario, but let's try to make things a bit more complex (and real).  

#### Dynamic process creation

Imagine we want to support multiple chat rooms. A client will start a new room with a name, and should be able
to send messages to any room she wants. The interface would be something like this:

```elixir
iex> Chat.Supervisor.start_room("first room")
iex> Chat.Supervisor.start_room("second room")

iex> Chat.Server.add_message("first room", "foo")
iex> Chat.Server.add_message("second room", "bar")

iex> Chat.Server.get_messages("first room")
["foo"]

iex> Chat.Server.get_messages("second room")
["bar"]
```

Let's start by changing the `Supervisor` to support that:

```elixir
# lib/chat/supervisor.ex

defmodule Chat.Supervisor do
  use Supervisor

  def start_link do
    # We are now registering our supervisor process with a name
    # so we can reference it in the `start_room/1` function
    Supervisor.start_link(__MODULE__, [], name: :chat_supervisor)
  end

  def start_room(name) do
    Supervisor.start_child(:chat_supervisor, [name])
  end

  def init(_) do
    children = [
      worker(Chat.Server, [])
    ]

    # We also changed the `strategy` to `simple_one_for_one`.
    # With this strategy, we define just a "template" for a child,
    # no process is started during the Supervisor initialization, just
    # when we call `start_child/2`
    supervise(children, strategy: :simple_one_for_one)
  end
end
```

And let's make the `Chat.Server` accept a name in the `start_link` function:

```elixir
# lib/chat/server.ex

defmodule Chat.Server do
  use GenServer

  # Just accept a `name` parameter here for now
  def start_link(name) do
    GenServer.start_link(__MODULE__, [], name: :chat_room)
  end

  #...
end
```

The problem now is that, as we can have a bunch of `Chat.Server` processes, we can't call all of them `:chat_room`.

```elixir
$ iex -S mix

iex> Chat.Supervisor.start_link
{:ok, #PID<0.107.0>}

iex> Chat.Supervisor.start_room "foo"
{:ok, #PID<0.109.0>}

iex> Chat.Supervisor.start_room "bar"
{:error, {:already_started, #PID<0.109.0>}}
```

Fair enough. When we try to start the second process it fails because a process named `:chat_room` is already started.
We need to register these process in another way.  

The `name` option is quite restrictive to what it will accept, though, we can't have a name like `{:chat_room, "room name"}`.
To quote the [documentation](http://elixir-lang.org/docs/stable/elixir/GenServer.html):

> The supported values are:  

> **an atom** - the GenServer is registered locally with the given name using Process.register/2.
>
> **{:global, term}** - the GenServer is registered globally with the given term using the functions in the :global module.
>
> **{:via, module, term}** - the GenServer is registered with the given mechanism and name.

The first option, an `atom`, is what we have been using so far and we know it's not enough for our needs now.  

The second option is used to register a process globally, across multiple nodes, and relies on a local `ETS` table. This also
means it requires synchronization across the entire cluster, which introduces some unnecessary overhead unless you actually need this behavior.

The third and last option is using what is called a `via tuple`, and that's exactly what we need to solve our problem. That's what the documentation says about it:

> The :via option expects a module that exports `register_name/2`, `unregister_name/1`, `whereis_name/1` and `send/2`.

It's hard to understand what this means without an example, so let's see this in action.

#### Using `via tuple`

`via tuple` is basically a way to tell `Elixir` that we will use a custom module to register our processes. It expects this
module to know how to do a few things:

* How to register a name, that can be any `Elixir` term, using the function `register_name/2`;
* How to unregister a name, using the function `unregister_name/1`;
* How to find the `pid` of a process with a given name, using `whereis_name/1`;
* And, finally, how to send a message to a given process, with `send/2`.

For this to work, these functions are expected to return a response in a specific format, the same way `OTP` expects
our `handle_call/3`, `handle_cast/2` and friends to follow some rules.

So let's implement a module that knows how to do that:

```elixir
# in lib/chat/registry.ex

defmodule Chat.Registry do

  use GenServer

  # API

  def start_link do
    # We register our registry (yeah, I know), with a simple name,
    # just so we can reference it in the other functions.
    GenServer.start_link(__MODULE__, nil, name: :registry)
  end

  def whereis_name(room_name) do
    GenServer.call(:registry, {:whereis_name, room_name})
  end

  def register_name(room_name, pid) do
    GenServer.call(:registry, {:register_name, room_name, pid})
  end

  def unregister_name(room_name) do
    GenServer.cast(:registry, {:unregister_name, room_name})
  end

  def send(room_name, message) do
    # If we try to send a message to a process
    # that is not registered, we return a tuple in the format
    # {:badarg, {process_name, error_message}}.
    # Otherwise, we just forward the message to the pid of this room.
    case whereis_name(room_name) do
      :undefined ->
        {:badarg, {room_name, message}}

      pid ->
        Kernel.send(pid, message)
        pid
    end
  end

  # SERVER

  def init(_) do
    {:ok, Map.new}
  end

  def handle_call({:whereis_name, room_name}, _from, state) do
    {:reply, Map.get(state, room_name, :undefined), state}
  end

  def handle_call({:register_name, room_name, pid}, _from, state) do
    # Registering a name is just a matter of putting it in our Map.
    # Our response tuple include a `:no` or `:yes` indicating if
    # the process was included or if it was already present.
    case Map.get(state, room_name) do
      nil ->
        {:reply, :yes, Map.put(state, room_name, pid)}

      _ ->
        {:reply, :no, state}
    end
  end

  def handle_cast({:unregister_name, room_name}, state) do
    # And unregistering is as simple as deleting an entry from our Map
    {:noreply, Map.delete(state, room_name)}
  end
end
```

Again, it's up to us to decide how this registry is going to work. Here we are using a simple `Map` to relate the room name with its pid.  
The implementation is straightforward if you are familiar with how a `GenServer` works (except for the not so usual return values).

Let's try that on `iex`:

```elixir
$ iex -S mix

iex> {:ok, pid} = Chat.Server.start_link("room1")
{:ok, #PID<0.107.0>}

iex> Chat.Registry.start_link
{:ok, #PID<0.109.0>}

iex> Chat.Registry.whereis_name("room1")
:undefined

iex> Chat.Registry.register_name("room1", pid)
:yes

iex> Chat.Registry.register_name("room1", pid)
:no

iex> Chat.Registry.whereis_name("room1")
#PID<0.107.0>

iex> Chat.Registry.unregister_name("room1")
:ok

iex> Chat.Registry.whereis_name("room1")
:undefined
```

The registry is working fine. We can register, unregister and find processes using their names, so let's start using it.

Our original problem was that we now can have multiple `Chat.Server` processes that are initialized by a `Supervisor`.
In order to send a message to a specific room, we want to use `Chat.Server.add_message("room1", "my message")`, so we need
to register our rooms with names like `{:chat_room, "room1"}` and `{:chat_room, "room2"}`. Here's how our `via tuple` implementation
makes it possible:

```elixir
# in lib/chat/server.ex

defmodule Chat.Server do
  use GenServer

  # API

  def start_link(name) do
    # Instead of passing an atom to the `name` option, we send 
    # a tuple. Here we extract this tuple to a private method
    # called `via_tuple` that can be reused for every function
    GenServer.start_link(__MODULE__, [], name: via_tuple(name))
  end

  def add_message(room_name, message) do
    # And the `GenServer` callbacks will accept this tuple the same way it
    # accepts a `pid` or an atom.
    GenServer.cast(via_tuple(room_name), {:add_message, message})
  end

  def get_messages(room_name) do
    GenServer.call(via_tuple(room_name), :get_messages)
  end

  defp via_tuple(room_name) do
    # And the tuple always follow the same format:
    # {:via, module_name, term}
    {:via, Chat.Registry, {:chat_room, room_name}}
  end

  # SERVER (no changes required here)
  # ...
end
```

What happens here is that every time we send a message to `Chat.Server` passing a room name,
it will find the `pid` of the process we want **via** the module we are providing (in this case, `Chat.Registry`).  
And this solves our problem, we can have as many `Chat.Server` processes as we want and we never need to know their `pid`s.  

There is still a big problem with this solution. Our registry never knows about processes that crashed and had to be restarted
by the `Supervisor`, and that means that when this happens the registry will hold a `pid` that is not valid anymore.  
Solving this issue should not be too hard, though, We will make our registry monitor all the process it is taking care of,
and when one of them crashed, we can safely remove it from our `Map`. 

```elixir
# in lib/chat/registry.ex

defmodule Chat.Registry do

  # ...

  def handle_call({:register_name, room_name, pid}, _from, state) do
    case Map.get(state, room_name) do
      nil ->
        # When a new process is registered, we start monitoring it
        Process.monitor(pid)
        {:reply, :yes, Map.put(state, room_name, pid)}

      _ ->
        {:reply, :no, state}
    end
  end

  def handle_info({:DOWN, _, :process, pid, _}, state) do
    # When a monitored process dies, we will receive a `:DOWN` message
    # that we can use to remove the dead pid from our registry
    {:noreply, remove_pid(state, pid)}
  end

  def remove_pid(state, pid_to_remove) do
    # And here we just filter out the dead pid
    remove = fn {_key, pid} -> pid  != pid_to_remove end
    Enum.filter(state, remove) |> Enum.into(%{})
  end
end
```

And let's make sure it works:

```elixir
$ iex -S mix

iex> Chat.Registry.start_link
{:ok, #PID<0.107.0>}

iex> Chat.Supervisor.start_link
{:ok, #PID<0.109.0>}

iex> Chat.Supervisor.start_room("room1")
{:ok, #PID<0.111.0>}

iex> Chat.Server.add_message("room1", "message")
:ok

iex> Chat.Server.get_messages("room1")
["message"]

iex> Chat.Registry.whereis_name({:chat_room, "room1"}) |> Process.exit(:kill)
true

iex> Chat.Server.add_message("room1", "message")
:ok

iex> Chat.Server.get_messages("room1")
["message"]
```

And now it doesn't matter how many times the `Supervisor` restart a `Chat.Server` process, when we send
a message to a room it will always find the correct `pid`.

#### Simplifying with gproc

This is as far as we will go with our example, but I just want to show a tool that helps us to simplify
our `via tuple` registry. That is [`gproc`](https://github.com/uwiger/gproc), an `Erlang` library.

Instead of telling `Elixir` to find the `Chat.Server` process via our `Chat.Registry` module, we will tell it
to find this process via `gproc`, and then we should be able to get rid of `Chat.Registry`.

Let's start by adding this dependency on `mix.exs`:

```elixir
# in mix.exs

defmodule Chat.Mixfile do
  # ...

  def application do
    [applications: [:logger, :gproc]]
  end

  defp deps do
    [{:gproc, "0.3.1"}]
  end
end
```

And then running `mix deps.get` to fetch the new `gproc` dependency.

With that in place, we should be able to change our `via tuple` definition to make it use `gproc` instead of `Chat.Registry`:

```elixir
# in lib/chat/server.ex

defmodule Chat.Server do
  # ...

  # The only thing we need to change is the `via_tuple/1` function,
  # to make it use `gproc` instead of `Chat.Registry`
  defp via_tuple(room_name) do
    {:via, :gproc, {:n, :l, {:chat_room, room_name}}}
  end

  # ...
end
```

`gproc` requires that keys are `tuples` with three values, in the form `{type, scope, key}`.  
Here we are using `:n` (for *name*, meaning that we can't have more than one process registered under a given key) as the type 
and `:l` (for *local*, meaning that the process is not registered across the entire cluster of nodes) as the scope. The key can be any `Elixir` term we want (e.g. `{:chat_room, "room1"}`).
I won't get into the details of all the possible `gproc` values, but you can check that in the [documentation](https://github.com/esl/gproc/blob/master/doc/gproc.md).

With this change, we can now remove the `Chat.Registry` module completely, and check that things are still working in the same way:

```elixir
$ iex -S mix

iex> Chat.Supervisor.start_link
{:ok, #PID<0.190.0>}

iex> Chat.Supervisor.start_room("room1")
{:ok, #PID<0.192.0>}

iex> Chat.Supervisor.start_room("room2")
{:ok, #PID<0.194.0>}

iex> Chat.Server.add_message("room1", "first message")
:ok

iex> Chat.Server.add_message("room2", "second message")
:ok

iex> Chat.Server.get_messages("room1")
["first message"]

iex> Chat.Server.get_messages("room2")
["second message"]

iex> :gproc.where({:n, :l, {:chat_room, "room1"}}) |> Process.exit(:kill)
true

iex> Chat.Server.add_message("room1", "first message")
:ok

iex> Chat.Server.get_messages("room1")
["first message"]
```

#### Where to go from here

We covered a lot of ground. The main takeaways are:

* Be careful when dealing with `pid`s directly, as they will change when a process is restarted and you may be holding a dead one;
* When you need to reference a single process (like when we had just one chat room), registering a this process with an `atom` name is usually enough;
* When you need to create processes dynamically (e.g. for multiple chat rooms) and have a way to reference them, using a `via tuple` is a viable solution;
* There are tools out there (like `gproc` that we used in our example) that will help you with that so you don't need to roll your own registry module.

That's not all, though. If you need global registration across all the nodes in a cluster, some other things should be considered as well.
`Erlang` has a [`global`](http://erlang.org/doc/man/global.html) module for global registration, [`pg2`](http://erlang.org/doc/man/pg2.html) for process groups, 
and even [`gproc`](https://github.com/uwiger/gproc), that we used in our examples, can help with that.

If this post piqued your interest, you should definitely check out [Elixir in Action](https://www.manning.com/books/elixir-in-action), by [Saša Jurić](https://github.com/sasa1977).
In this [repository](https://github.com/brianstorti/elixir-registry-example-chat-app) you can find all the code we wrote in this example.
