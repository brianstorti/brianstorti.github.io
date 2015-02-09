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
You can also access the registers in insert mode with `ctrl-r` + register name, like in `ctrl-r r`.
