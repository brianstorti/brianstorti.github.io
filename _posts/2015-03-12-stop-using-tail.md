---
layout: post
title: Stop using tail -f (mostly)
meta: Stop using tail -f
draft: false
---

I still see a lot of people using `tail -f` to monitor files that are changing, mostly log files. If you are one of them, let me show you a better alternative: `less +F`

The `less` documentation explains well what this `+F` is all about: 
> Scroll  forward,  and keep trying to read when the end of file is reached.  Normally this command would be used when already at the end of the file.  It is a way to monitor the tail of a file which is
> growing while it is being viewed.  (The behavior is similar to the "tail -f" command.)

So it says that it's similar to `tail -f`, but why I think it's better?

Simply put, it allows you to switch between navigation and watching mode. We all have been there: You are watching a file with `tail -f`, and then you need to search for something in this file, or just navigate up and down.
Now you need to exit `tail` (or open a new shell), and `ack` this file or open it with `vim` to find what you are looking for. After that, you run `tail` again to continue watching the file. There's no need to do that when
you are using `less`.

Let's say you want to watch the file `production.log`:

```bash
$ less +F production.log

Important
log
information
here

Waiting for data... (interrupt to abort)
```

Here you have pretty much the same behavior you'd get with `tail`.  

Now let's say something interesting appears, and you want to search all the occurrences of "foo". You can just hit `Ctrl-c` to go to "normal" `less` 
mode (as if you had opened the file without the `+F` flag), and then you have all the normal `less` features you'd expect, including the search with `/foo`. You can go to the next or previous occurrence with `n` or `N`,
up and down with `j` and `k`, create marks with `m` and do all sort of things that `less(1)` says you can do.

Once you are done, just hit `F` to go back to watching mode again. It's that easy.


# When not to use less

When you need to watch multiple files at the same time, `tail -f` can actually give you a better output. It will show you something like this:

```bash
$ tail -f *.txt

==> file1.txt <==
content for first file

==> file2.txt <==
content for second file

==> file3.txt <==
content for third file
```

When a change happens, it prints the file name and the new content, which is quite handy.

With `less`, it would be like this:

```bash
$ less +F *.txt

content for first file
```

It shows the content of just one file at a time. If you want to see what's happening in the second file, you need to first `Ctrl-c` to go to normal mode, then type `:n` to go to the next buffer, and then `F` again to go back to the watching mode.

Depending on your needs, it might still be worth to use `less` for multiple files, but most of the time I just go with `tail` for these cases. The important thing is to know the tools that we have available and use the right one 
for the job at hand.


>> Статья на сайте softdroid.net: <a href="http://softdroid.net/perestante-ispolzovat-f-chasto">Блог о файлах и данных: Перестаньте использовать -f (часто)</a>
