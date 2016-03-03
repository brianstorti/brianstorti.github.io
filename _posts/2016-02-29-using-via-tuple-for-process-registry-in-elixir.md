---
layout: post
title: Process registry in Elixir
meta: Process registry in Elixir
draft: false
---

Processes in `Elixir` (and `Erlang`, for that matter) are identified with a unique process id, the `pid`.  
That's what we use to interact with them. We send a message to a `pid` and the VM take care of delivering it to the
correct process.


#### No registry at all



{:ok, pid} = ChatRoom.start_link
ChatRoom.send_message(pid, "some message")

#### Introducing a Supervisor
Kill process, can't send messages anymore
Create supervisor
Kill process, shows that process is restarted but pid changed, so our reference does not work anymore
Register chat room process with name: :chat_room
Kill process and show that our reference still works

#### Dynamic process creation
One process per chat room
Create supervisor with simple_one_for_one and introduce start_child
What about the process name?

#### Creating a process registry
Create registry GenServer with Map for process -> pid 
Same problem of holding pids. when a supervisor restart this process, our reference is not valid anymore

#### Using `via tuple`
Introduce `via tuple`

> {:via, module, term} - the GenServer is registered with the given mechanism
> and name. The :via option expects a module that exports register_name/2,
> unregister_name/1, whereis_name/1 and send/2. 

Kill process and show that it will works fine

#### Using gproc
Erlang library
Cool that you have access to the entire Erlang ecosystem. Mix will use rebar to install it

> There is a small twist due to the gproc interface. Gproc requires that keys
> are trip- lets in the form {type, scope, key}. You can check for details in
> the gproc documen- tation (http://mng.bz/sBck); but in this case, you need a
> triplet in the form of {:n, :l, key}, where :n indicates a unique
> registration (only one process can register itself under a given key) and :l
> stands for a local (single-node) registration. Of course, you can use an
> arbitrary term as a key.

http://blog.rusty.io/2009/09/16/g-proc-erlang-global-process-registry/

#### Conclusion
