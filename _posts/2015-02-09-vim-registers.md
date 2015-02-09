---
layout: post
title: Vim registers
meta: vim registers
draft: true
---

Vim's registers are that kind of stuff that you don't think you need, until you learn about them. After that, they become essential in your normal workflow, 
and it's hard to let them behind. Saying that, it's still incredible how many people use vim for years without knowing how to make proper use of registers.
Bear with me and you won't be one of them.

### If you have no idea what I'm talking about

You can think of registers as a bunch of spaces in memory that `vim` uses to store some text. Each of these spaces has a identifier, so it can be accessed later.  
It's no different than when you copy some text to your clipboard, except that you usually have just one clipboard to copy to, while `vim` allows you to have multiple
places to store different texts.

### The basic usage

Every register is accessed using a double quote before its name. For example, we can access the content that is in the register `r` with `"r`.

You could add the selected text to the register `r` by doing `"ry`. By doing `y` you are copying (yanking) the selected text, and then adding it to the register `"r`.
To paste the content of this register, the logic is the same: `"rp`. You are `p`asting the data that is in this register.  
You can also access the registers in insert mode with `ctrl-r` + register name, like in `Ctrl-r r`. It will just paste the text in your current buffer.

### The unnamed register

Vim has a unnamed, or default, register, called `""`. Any text that you delete (with `d`, `c`, `s` or `x`) or yank (with `y`) will be placed there, and that's what vim uses to `p`aste, when no explicit register is given.
A simple `p` is the same thing as doing `""p`.

##### Never lose a yanked text again

It already happened to all of us. We yank some text, than delete some other, and when we try to paste the yanked text, it's not there anymore, `vim` replaced it with the text that you deleted, then you need
to go there and yanked that text again.  
Well, as I said, `vim` will always replace the unnamed register, but of course we didn't lose the yanked text, `vim` would not have survived that long if it was that dumb, right?

Vim automatically populates what is called the **numbered registers** for us. As expected, these are registers from `"0` to `"9`.  
`"0` will always have the content of the latest yank,
and the others will have last 9 deleted text, being `"1` the newest, and `"9` the oldest. So if you yanked some text, you can always refer to it using `"0p`.
