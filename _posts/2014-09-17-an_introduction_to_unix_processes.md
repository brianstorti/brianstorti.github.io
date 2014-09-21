---
layout: post
title: An introduction to UNIX processes
---

Processes are a very important piece in the UNIX world. Basically, almost every program that you execute is running
in a process.  
Although you may not need to interact directly with them all the time, you are certainly depending on
them to get anything done in a UNIX system.

## First things first: What is a process?

This is not the formal definition of a process, but I like to imagine them as a container. Inside this container
there is program running (`vim`, for instance), a bunch of metadata properties that describe the program (who's running it,
what is its id and so on), and this container can receive and send messages to other containers.  
A more formal definition is that a process is, quoting wikipedia, "an instance of a computer program that is being executed".

## Processes properties

The basic command to see the list of running processes is `ps` (process status).  
Run it in your terminal and you should see something like this:


```bash
$ ps

  PID TTY           TIME CMD
28838 ttys000    0:00.16 -zsh
13833 ttys002    0:00.90 -zsh
27267 ttys002    0:06.82 vim
```

We can pass a `-o` parameter to format the ouput with the information that we want. Let's run it again asking
for all the metadata we want to talk about:

```bash
$ ps -o pid,ppid,tty,uid,args

  PID  PPID TTY        UID      ARGS
28838 28836 ttys000  1935087709 -zsh
13833 13832 ttys002  1935087709 -zsh
27267 13833 ttys002  1935087709 vim
```
**PID**: Every process has an id associated to it. It's an unique identifier, and that's how we can reference a specific process.  

**PPID**: That's the parent's PID. Every (well, almost) process has a parent process, the process that was responsible for its creation.  

**TTY**: This is a identifier of the terminal session that triggered this process. That's called the `controlling terminal`. 
Almost every process will be attached to a terminal (except for daemons, that we'll talk about later). In my example you can see that
I have two terminal sessions running (`ttys000` and `ttys0002`). You can check your curreny tty with the, surprise, `tty` command:

```bash
$ tty
/dev/ttys000
```

**UID**: This is the user id. It's the identifier for the user that's the owner of this process, and that's what will define the permissions
this process will have.  
You can check your user id with the command `id`:

```bash
$ id -u brianstorti
1935087709
```

**ARGS**: The command (followed by its arguments) that's running in this process.  

There are many more properties related to a process, like the CPU / memory usage percentage, the start time and so on. You can check the entire
list in the `ps` manpage:

```bash
man ps
```

Just search for `KEYWORDS` and you see a huge list of properties. The ones that I just described are the more commonly used, though.


## How processes are born

Processes creation is achieved in 2 steps in a UNIX system: the `fork` and the `exec`.

Every process is created using the `fork` system call. We won't cover system calls in this post, but you can imagine them as a way
for a program to send a message to the kernel (in this case, asking for the creation of a new process).  

What `fork` does is create a copy of the calling process. The newly created process is called the child, and the caller is the parent. This
child process inherits everything that the parent has in memory, it's an almost exact copy (`pid` and `ppid` are different, for instance).  
One thing to be aware of is that if a process is using 200MB of memory, when it forks a child, the newly created process will use more 200MB.
This can easily become an accidental "fork bomb", that will consume all the available resources of the machine.

The second step is the `exec`. What `exec` does is **replace** the current process with a new one. The caller process is gone forever, and the new
process takes its place. If you try to run this command in a terminal session:

```bash
exec vim
```

`vim` will be opened normally, as it was a direct call to it, but as soon as you close it, you will see that the terminal is gone as well. So
here's what happened:  
You had a shell process running (`bash`, `zsh` or similar). In the moment that you called `exec`, passing `vim` and a parameter, it **replaced**
the `bash` process with a `vim` process, so when you close vim, there is no shell there anymore.

You will see this fork + exec pattern all over the place in a UNIX system. If you are running a bash process, when you call, say, `ls`, to list your files,
what actually is done is exactly this. The `bash` process calls `fork` to create an exact copy of itself, then call `exec`, to replace this copy with the
`ls` process. When the `ls` process exits, you are back to the parent process, that is `bash`. And talking about a process exiting...

## Processes always exit with an exit code

Every process exits with an exit code, that is between 0 and 255. There are [well accepted meanings](http://tldp.org/LDP/abs/html/exitcodes.html) for some
of them, but they are really just numeric values that you can handle as you want (although it's a good idea to keep the conventions).  
What is important to know is that the `0` is considered a successful exit code, while all the other indicate different types of errors.  

We can try that with the `cd` command (or any other you want, actually). Notice that `$?` can be used to represent the exit code of the
last process that was executed:

```bash
$ cd
$ echo $?
0

$ cd nop
cd:cd:13: no such file or directory: nop

$ echo $?
1
```

The status `0` represents that the process was executed successfully, while `1` represents a failure, when we tried to cd into an inexisting directory.  
The parent process then can read this code through the `wait` system call.  
If the child process exits and, for some reason, the parent fails to call `wait`,
we have what is called a **zombie process**.

## Zombie and orphan processes

Zombies and orphans processes are sometimes wrongly mixed together, but they are two different things.  

A process becomes a zombie when it exits, but its parent doesn't call `wait`. The process doesn't really exist anymore, but it still appears in the
process table (like the one you see when you run the `ps` command). The table will show a status `Z` for the zombies.  
This state is possible because the kernel can not fully dispose a process when it exits, otherwise no one would be able to read its exit code, so
it just waits until the parent performs a call to `wait`, and then it can be fully removed.  
Every process stay in a zombie state, at least for a short period of time, between the moment it exits, and the moment the parent reads its exit code.

A process becomes an orphan when it's still running, but its parent exits. What happens is that the child process is "adopted" by the initial process,
the first process that is executed in the system, ususally called `init` (`launchd` if you are on a Mac OS). The PPID (parent id) of an orphan process
with be `1`.  
A process can be orphaned unintentionally, when the parent process crashed, for instance, but it also can be orphaned intentionally, usually when you want
a long running process to be detached from a user session, as is the case for `daemons` processes.

## Daemon processes

A `daemon` process is, simply speaking, a process that runs in the backgroung, and is not attached to a controlling terminal. Database and web servers are
good examples of daemons. There are also a bunch of daemons that are responsible for keeping your system working as it's.  

There is one specially important `daemon`, the first process created on the system: the `init` process. It's the grandparent of all the other processes.  
The `init` process can spawn new processes that will be `daemons`, or a process can become a `daemon` by being intentionally made an orphan, as we saw 
before (forking a child and immediatelly exiting).
You'll also notice that, by convention, `daemons` names usually end with a "d": `syslogd`, `sshd`, `httpd`, and so on.  

But if these `daemons` are not attached to a controlling terminal, how can someone actually terminate these processes? Well, one way is by sending them a signal.

## Signals

Remember when I said that I liked to imagine processes as containers, and that these containers could send messages to each other? Well, that's exactly what
signals are, messages that are sent from one process to another.

The system call used to send a process a signal is `kill`. This communication mechanism was originally created to terminate processes, that's why it is named
like that, but it actually just send a message (that might or might not be meant to terminate the receiver process).

When a process receives a signal, it can carry out the default action for that signal, execute a signal handler function, or, with a few exceptions, just ignore it.

You can run `kill -l` to see the list of available signals that can be sent. Each one of these signals also have an equivalent numeric value. For instance,
one of the most used signals, `KILL`, can be represented by the number `9`.

You can send a signal to a process with the `kill` command. For instance, if you want to kill that `vim` process that process that is running (with a PID 27267),
you can run any of these commands:

```bash
$ kill -KILL 27267 
$ kill -SIGKILL 27267 
$ kill -9 27267 
```

That's also what happens when you hit `Ctrl-c` to terminate a program in your terminal, a `SIGINT` signal (INTERRUPT) is sent to the running process, and,
as a consequence, it should terminate.

With the exception of `SIGKILL` and `SIGSTOP`, processes can `trap` a signal to perform some custom action (or just ignore it). That's why sometimes `Ctrl-c`
doesn't seem to work, the target process probably traped it to do something (e.g. remove temporary files or close connections) before actually exit.

One interesting exception is the `init` process, that can ignore even a `SIGKILL` or a `SIGSTOP` signal. The reason is that the kernel forces a system 
crash if the `init` process terminates, so it will not deliver any fatal signal to this process.


## Summarizing

* A process is an instance of a running program;
* Processes have some properties related to it (pid, ppid, tty, etc.);
* Processes are created in a two step process: `exec` and `fork`;
* Processes always exit with an exit code;
* A process is a zombie if it is already dead but its parent still didn't read its exit code with `wait`;
* A process is an orphan if it is still alive but its parent isn't. The `init` process becomes the new parent;
* A daemon is a process that runs in the backgroung, and is not attached to a controlling terminal;
* Signals are messages sent from one process to another.
