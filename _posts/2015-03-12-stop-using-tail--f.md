---
layout: post
title: Stop using tail -f
meta: Stop using tail -f
draft: false
---

I still see a lot of people using `tail -f` to monitor files that are changing, mostly log files. If you are one of them, let me show you a better alternative: `less +F`

The `less` documentation explains well what this `+F` is all about: 
> Scroll  forward,  and keep trying to read when the end of file is reached.  Normally this command would be used when already at the end of the file.  It is a way to monitor the tail of a file which is
> growing while it is being viewed.  (The behavior is similar to the "tail -f" command.)

So it says that it's similar to `tail -f`, but why I think it's better?
