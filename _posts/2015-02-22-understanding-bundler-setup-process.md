---
layout: post
title: Understanding Bundler's setup process
meta: Understanding Bundler's setup process
---

If you work with `Ruby`, chances are that you are using [`Bundler`](http://bundler.io) quite a lot. It's the *de facto* solution for
dependency management, and it's hard to find a project without a `Gemfile`. What is not part of the common knowledge,
though, is how it works. More specifically, how does it make your code see just the dependencies that it should see and nothing else?
Let's look into `Bundler`'s code to find out.

### The example project

To make it easier to understand what `Bundler` is doing, I'll create a simple `sinatra` project.

```ruby
# app.rb
require 'sinatra'

get '/test' do
  'test'
end
```

So far so good. As long as I have `sinatra` installed, it should work just fine.  
The problem is that we don't like the idea that everyone that is going to run this code needs to **know** what the dependencies are (`sinatra` in version `1.4.5`),
so we create a `Gemfile` to let `Bundler` do that for us:

```ruby
# Gemfile
source "https://rubygems.org"

gem "sinatra"
```

Now anyone that gets this code can just run `bundle install` and all the dependencies should be there, right? Well, not so fast.

##### The hidden dependency

Someday I decide that this `/test` route is too boring, and it should now actually returns Metallica's "The Unforgiven" lyrics. So I just go there and run `gem install vagalume`
to get a `gem` that does that, and change my code:

```ruby
require 'sinatra'
require 'vagalume'

get '/test' do
  result = Vagalume.find("Metallica", "The Unforgiven")
  result.song.lyric
end
```

I run the app and everything seems to be working fine. I commit my code.

As soon as someone else tries to run the app, it breaks badly, saying that it `cannot load such file -- vagalume`.

##### What just happened here? 

The problem is that, although you have a `Gemfile` where you list your dependencies, you didn't tell `Bundler` that your app should see **just** those `gems`.  
This `require 'vagalume'` is actually checking all the `gems` that you have installed in your systems, not just the ones listed in the `Gemfile`, and that is not good.

### Enters `bundler/setup`

Let's start to fix this. If we go there and add this line in the top of the file:

```ruby
require 'bundler/setup'
```

You should see that the app starts to break with that same error (`cannot load such file -- vagalume (LoadError)`), even if you have `vagalume` installed. That's good,
`Bundler` is now making sure that our code sees just what it should see, that is, the `gems` listed in the `Gemfile`.


##### Understanding what is happening

To put it shortly, what `Bundler` is doing is removing from the `$LOAD_PATH` everything that is not defined in the `Gemfile`. The `$LOAD_PATH` (or just `$:`) is
the global variable that tells `Ruby` where it should look for things that are `require`d, so if a dependency is not in the `Gemfile`, it's not going to be in the `$LOAD_PATH`,
and then `Ruby` has no way to find it.

##### Show me the code

[This](https://github.com/bundler/bundler/blob/master/lib/bundler/setup.rb) is the file that is loaded when we `require 'bundler/setup'`, and the important thing here is the
[`Bundler.setup`](https://github.com/bundler/bundler/blob/master/lib/bundler/setup.rb#L8) call. This setup first [cleans the load path](https://github.com/bundler/bundler/blob/master/lib/bundler/runtime.rb#L11),
and then [activates](https://github.com/bundler/bundler/blob/master/lib/bundler/runtime.rb#L18) just the `gems` that are defined in the `Gemfile`, which basically means 
[adding them to the `$LOAD_PATH` variable](https://github.com/bundler/bundler/blob/master/lib/bundler/runtime.rb#L39).

##### And that is also what happens with `bundle exec`
This is good moment to understand what happens when we use `bundle exec` to run a command.  
`Bundler` will simply add the value `-rbundler/setup` to the environment variable `$RUBYOPT`. [Here is where it's done](https://github.com/bundler/bundler/blob/master/lib/bundler/shared_helpers.rb#L81).  
This will tell `ruby` to require `bundle/setup` before running any command, and that will let `Bundler` do its magic to the `$LOAD_PATH`, as we just checked.

### Bundler on Rails

As you probably guessed, when you are working with `Rails` you don't really need to worry about this. There's no magic, `Rails` is just calling the same `bundler/setup` for you.  
You can check in `config/boot.rb`, that is where this is done. Also, in `config/application.rb`, `Rails` will call `Bundler.require` for you, that is just a convenience that will auto require
all the gems that are in the `$LOAD_PATH` so you don't need to.  
You could do the same thing in that simple `sinatra` app, and then remove all those `requires`:

```ruby
# app.rb

require 'bundler/setup'
Bundler.require

# there is no need to manually require the dependencies
# anymore, as we just called Bundler.require
# require 'sinatra'
# require 'vagalume'

get '/test' do
  result = Vagalume.find("Metallica", "The Unforgiven")
  result.song.lyric
end
```

### Wrapping up

And we can see, the mechanism that makes `Bundler` work the way it does is not that complex. It's just changing the `$LOAD_PATH` (that is not to say that `Bundler` itself is not complex, it actually
does a lot more that what I showed here). Not understanding how it works, though, could make debugging a problem much more painful.  
It is worth to take some time to understand at least the basics that make the tools you deal with every day work. It will almost certainly save you some precious time in the future.
