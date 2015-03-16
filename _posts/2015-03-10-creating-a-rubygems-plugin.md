---
layout: post
title: Creating a RubyGems plugin
meta: Creating a RubyGems plugin
draft: false
---

Do you know when you install a `gem` and it adds a custom command to `RubyGems`? Then you can just run `gem <custom-command> <params>` and it does something cool?
Well, that is just a `RubyGems` plugin, and although it's not very well documented, it's not that hard to create one.

# Our goal

Our goal here is just to understand what are the pieces that we need to put together to create one of these plugins. We are not going to create something that is amazingly useful.
Here's what it will do: It will add a `repo` command, that will just open a GitHub repository in your browser.

```bash
$ gem repo ruby/ruby

# should open http://github.com/ruby/ruby in your browser
```

So let's get our hands dirty.

# It's just a gem

A `RubyGems` plugin is just a normal `gem`, with some specific characteristics. To create a `gem` you can use any template or generator you like. I'll use `bundle gem repo` to create the skeleton for our plugin.

```bash
$ bundle gem repo

├── Gemfile
├── LICENSE.txt
├── README.md
├── Rakefile
├── bin
│   ├── console
│   └── setup
├── lib
│   ├── repo
│   │   └── version.rb
│   └── repo.rb
└── repo.gemspec
```

And the first step is to update the `repo.gemspec` file with your plugin details. It could look something like this:

```ruby
# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'repo/version'

Gem::Specification.new do |spec|
  spec.name          = "repo"
  spec.version       = Repo::VERSION
  spec.authors       = ["Your name"]
  spec.email         = ["your@email.com"]

  spec.summary       = %q{Opens github repo}
  spec.description   = %q{Opens github repo}
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.8"
  spec.add_development_dependency "rake", "~> 10.0"
end
```

After you run `git add .`, you should be able to build your gem with `gem build repo.gemspec` and check that a file called `repo-0.1.0.gem` was created. We are good to go!

# The RubyGems requirements

`RubyGems` will look for a file called `rubygems_plugin.rb` in the root of the `require_path` that was defined in the gemspec. In our case, it's in the `lib` directory, so we will create this file there:

```ruby
# lib/rubygems_plugin.rb

require "rubygems/command_manager"

Gem::CommandManager.instance.register_command(:repo)
```

Here we are just registering a new command, so `RubyGems` will be able to find it when someone tries to execute our `gem repo`.  
That's the same way the builtin commands are registered, as you can see [here](https://github.com/rubygems/rubygems/blob/master/lib/rubygems/command_manager.rb#L99).

After our custom command is registered, we need to create the class that will be executed when someone calls this command. `RubyGems` will look for a class in `rubygems/commands`, that 
matches our command name. In our case, `repo_command.rb`.

```ruby
# lib/rubygems/commands/repo_command.rb

class Gem::Commands::RepoCommand < Gem::Command
  def initialize
    super("repo", "Open github repository")
  end

  def execute
  end
end
```

We create our `Gem::Commands::RepoCommand`, that extends from `Gem::Command`. The `execute` method is our guy, it's the one that will be called when we run the command.  
Again, that's exactly how the builtin commands work. If you check [this directory](https://github.com/rubygems/rubygems/tree/master/lib/rubygems/commands), you will see all these commands.
It's also a great place to find inspiration and see how the commands that you use every day work.

# Implementing the functionality

Implementing our functionality is just a matter of calling a command in this `execute` method. I'll just use the `open` command here, that should work just for OS X, fell free to implement it the way you like.

```ruby
def execute
  repo = options[:args].first
  system "open http://github.com/#{repo}"
end
```

Notice that we have this `options` hash with some useful information, like the list of arguments we received. In this case, we just need the first one, that is the repository name.

And that should be it! Here's the final structure that we should have:

```
├── Gemfile
├── LICENSE.txt
├── README.md
├── Rakefile
├── lib
│   ├── repo
│   │   └── version.rb
│   ├── rubygems
│   │   └── commands
│   │       └── repo_command.rb
│   └── rubygems_plugin.rb
├── repo-0.1.0.gem
└── repo.gemspec
```

# Installing the plugin

Let's install this plugin to make sure it works.  
First, remove the old `repo-0.1.0.gem` that we created before:

```bash
$ rm repo-0.1.0.gem
```

Then make sure all your files are tracked:

```bash
$ git add .
```

Rebuild you gem:

```bash
$ gem build repo.gemspec
```

And install the plugin:

```bash
$ gem install repo-0.1.0.gem

# Successfully installed repo-0.1.0
# Parsing documentation for repo-0.1.0
# Done installing documentation for repo after 0 seconds
# 1 gem installed
```

Now the `repo` command should already be available:

```bash
$ gem repo ruby/ruby

# should open http://github.com/ruby/ruby in your browser
```

# Extra

There are a few methods that you can override in your class to better explain how the command works. I couldn't find them documented anywhere, but you can just check the [base command class](https://github.com/rubygems/rubygems/blob/master/lib/rubygems/command.rb). 
The methods that you can override have a comment explaining its purpose.  
One example is the `usage` method, that I probably don't need to explain. These information are shown when someone runs `gem help <command>`. You can check `gem help install` for an example of a very well documented command.

In the [RubyGems website](http://guides.rubygems.org/plugins/) you can find a list of plugins. There are certainly hundreds more out there, but this is a good list to start with and see how things are done.

# Update

Since people seem to be more interested in building `RubyGems` plugins than I thought, I decided to create a plugin generator. You can find it on [my github](https://github.com/brianstorti/rubygems_plugin_generator).
It's basically an automation for the things I covered here.
