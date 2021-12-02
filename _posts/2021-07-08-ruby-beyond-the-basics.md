---
layout: post
title: Ruby beyond the basics
meta: Ruby beyond the basics
draft: true
---

Ruby is a fairly straightforward language and it's usually not that hard to get started, specially if you already know some other language. There are plenty of resources online that will help you get your foot wet, but after you learn the basics, to get a more in-depth knowledge is not that easy.  In this interactive course I want to cover several topics that go beyond what you'll learn on basic tutorials, and I'll have succeeded if you know enough to be able to understand the code from your favorite frameworks and libraries.

# Open Classes

Ruby is an object-oriented programming language, so, as you'd expect, we are constantly working with classes and instances of these classes.

```
class Person
  def say_hello
    puts "Hello!"
  end
end

person = Person.new
person.say_hello # Hello
```

There's not much going on here. We create a class with a `say_hello` method, then instantiate it and call this method, no big deal.

What is a bit more interesting is that in Ruby we can do things like this:

```
class Person
  def say_hello
    puts "Hello!"
  end
end

class Person
  def say_hi
    puts "Hi!"
  end
end

person = Person.new
person.say_hello # Hello
person.say_hi # Hi
```

This may seem weird at first, as we're apparently defining two classes with the same name, but that's totally fine in Ruby.

Ruby has the concept of open classes, which means we're not really redefining the class, just opening an existing class and adding more things to it or changing what was already there. This is also referred to as "Monkey Patching".

We can also replace something that's already there:

```
class Person
  def say_hello
    puts "Hello!"
  end
end

class Person
  # redefining a method with the same name will replace the
  # previous one
  def say_hello 
    puts "Whoops!"
  end
end

person = Person.new
person.say_hello # Whoops
```

And we can also do that for existing Ruby classes. For example, we can make people really confused with something like this:

```
class Integer
  def +(number)
    self - number
  end
end

puts 5 + 2 # 3
```

Here we are just opening the `Integer` class and redefining the `+` method.

Of course, this is something you _can_ do, but it doesn't mean you should. But there are cases where that can be super helpful. `Rails`, for example, use this technique a lot to provide a nicer experience. When using `Rails` you can call something like `10.days.ago`, or `5.days.from_now` to get the date you want, without needing to figure out how to do that calculation yourself.

Let's try to implement that ourselves

```
class Integer
  def days
    Day.new(self)
  end
end

class Day
  def initialize(n)
    @n = n
  end

  def ago
    Time.now - @n * 24 * 60 * 60
  end

  def from_now
    # write the code to add the number of days
  end
end

puts 10.days.ago
puts 10.days.from_now
```

Even though this can be super helpful, it can also very quite dangerous, as we have seen with our example redefining `Integer#+`.
The problems with Monkey Patching are not always as clear as this `Integer` example.

Let's try another example, where we open the `Array` class and add the `replace` method, which will replace the elements of this array with a new given value.

```
# we open the `Array` class
class Array
  # and define a `replace` method
  def replace(to_replace, replacement)
    # that will iterate over the elements of the array and replace
    # elements that are == our `to_replace` parameter

    map { |element| element == to_replace ? replacement : element }
  end
end

puts [1,2,3,5].replace(5, 4) # [1,2,3,4]
```

This seems innocent enough, but then we try to run our test suite (in the best case scenario) and find out a lot of unrelated things are breaking. So what's the problem here?

The issue is that the `Array` class already has a `replace` method, that does something completely different from what we did here, and that's the behaviour other parts of our codebase were expecting.

This is also a problem when we have multiple different libraries redefining the same methods. Depending on the order that these libraries are loaded you end up with a different method definition, and adding a new library can break something completely unrelated. That's not super fun.

Thinking about this `Ruby` introduced `Refinements`, which is a way to scope our, well, refinements to existing classes. Here's an example.

```
# we define a module where our refinements will live
module OurArrayRefinement
  # we use the `refine` keyword to tell Ruby which class we're refining
  refine Array do
    # here it's just like a normal class where we can define our methods
    def replace(to_replace, replacement)
      map { |element| element == to_replace ? replacement : element }
    end
  end
end

# A normal class not using our refinements
class RawClass
  def test_replace
    [1,2,3,5].replace([1,2,3])
  end
end

# A class `using` our refinements
class RefinedClass
  using OurArrayRefinement

  def test_replace
    [1,2,3,5].replace(5, 4)
  end
end

puts RawClass.new.test_replace
puts RefinedClass.new.test_replace
```

As you can see, we can tell exactly where our refinement will be activated, and make sure it's only used in places we actually want it.

There's no right or wrong (well, maybe redefining `Integer#+` was actually wrong), sometimes it makes sense to have a project-wide monkey patch, but we should think if our change is something that could be scoped to a few specific places where we actually need it.

Finally, as you'll eventually find a case where you just can't figure out where a specific method definition is coming from, `Ruby` has a very handy method that will show exactly the file and line where a method defined.


```
class Array
  def replace(to_replace, replacement)
    map { |element| element == to_replace ? replacement : element }
  end
end

puts [].method(:replace).source_location
```

The output is probably not super clear on this interactive shell, but in a real project you will see something like

```
["/path/to/my/file.rb", 32]
```

# Singleton Classes (and methods)

Every object in `Ruby` is associated with two classes: The one the instance was created from, and another anonymous, hidden class, called the `Singleton` class. This is a class that's specific to this object.

```
class Person
end

person = Person.new
puts person.class # Person
puts person.singleton_class # #<Class:#<Person:0x00007fcd5c89bda0>>
```

The idea for this Singleton class is to hold methods that are specific to a single instance. Here's an example you may have seen before:

```
class Person
end

bob = Person.new
alice = Person.new

def bob.say_hi
  puts "Hi!"
end

bob.say_hi # Hi!
alice.say_hi # NoMethodError
```

Here we have two instances: `bob` and `alice`. These two instances are associated with the `Person` class, which doesn't have any methods. 
We're then defining a singleton method for `bob`, which means we can now call `bob.say_hi`, but not `alice.say_hi`, as this method was defined only in `bob`'s Singleton class.

Another syntax that can be used to do the same thing is

```
class Person
end

bob = Person.new
alice = Person.new

class << bob
  def say_hi
    puts "Hi!"
  end
end

bob.say_hi # Hi!
alice.say_hi # NoMethodError
```

The effect is exactly the same, we're just using the notation `class << object` to define this method in the object's Singleton class. This can be useful when you're adding more than a single method, as you don't need to define everything with the `def object.method` notation.

You may have seen this syntax being used to define a class method, so let's understand what's happening here.

```
class Person
  class << self
    def say_hi
      puts "Hi!"
    end
  end
end

Person.say_hi
```

We are using the same `class << object` syntax, leveraging the fact that `self` refers to the class in this case, which means we are opening the `Person` class Singleton class, which sounds very confusing.

In Ruby, with a few exceptions, everything is an object. That includes classes, which are simply instances of the `Class` class.

```
puts Array.class
puts String.class
puts Integer.class
puts Class.class # Even the Class's class is `Class`
```

So knowing that classes are also objects (that is, instances of the `Class` class), means we can use their Singleton class to create what is normally known as class methods. So a class method is nothing more than a singleton method, defined in a class' singleton class.

```
class Class
  # We define a class that is available for every instance of `Class`, that is,
  # every class, like `Integer`, `Array` and our `Person`
  def defined_on_class
    puts "defined on `Class`"
  end
end

class Person
  # Then we have a normal method that will be available only for instances of
  # `Person`
  def defined_on_person_class
    puts "defined on person instance"
  end

  class << self
    # And a singleton method, which means the method is available only for this
    # instance of our `Class` object (i.e. for our `Person` object), making it
    # a class method
    def defined_on_person_singleton_class
      puts "defined on person singleton class"
    end
  end
end

Integer.defined_on_class
Person.defined_on_class
Person.defined_on_person_singleton_class
person = Person.new
person.defined_on_person_class
```

If you think about classes as normal objects, everything will make more sense.

Another interesting thing to note is that this definition can happen anywhere, not necessarily inside the class, the only difference is that we can't use `self` in these cases.

```
def add_singleton_method_to(object)
  class << object
    def it_works
      puts "it works!"
    end
  end
end

add_singleton_method_to(Integer)
Integer.it_works

string = ""
add_singleton_method_to(string)
string.it_works
```

And lastly, something that probably doesn't have any practical use, but if you think about it, as a Singleton class is itself just an instance of `Class`, it also has a Singleton class, that has a Singleton class, that has a...

```
foo = ""
class << foo
  class << self
    class << self
      def wat?
        puts "wat?"
      end
    end
  end
end

foo.singleton_class.singleton_class.wat?
```

# Methods
