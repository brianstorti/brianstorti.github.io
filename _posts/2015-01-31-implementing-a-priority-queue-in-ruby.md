---
layout: post
title: Implementing a Priority Queue in Ruby
draft: true
---

The other day I had to use a priority queue to solve a problem. It was a `Java` project, so I already had the `PriorityQueue` class ready to be used.
After the code was done, I started to wonder what a solution in `Ruby` would look like. And then I discovered that `Ruby` does not have a 
priority queue implementation in its standard library. How hard could it be to implement my own?


### First, some definitions

I just want to define what a queue and a priority queue are before we go to the implementation. If you are already comfortable with these definitions,
fell free to jump to the next section.

A queue is a data structure in which the items added first, will be the first to be removed, also known as first-in first-out. Ruby has a queue implementation
in its standard library, and the usage is quite simple: 

```ruby
q = Queue.new
q << 1
q << 2
q << 3

q.pop # => 1
```

A priority queue is like a queue, where you remove items from the front of the list. The difference is that each element has a priority, and the order of the items
inside the queue is determined by this priority, so the first item to be removed will be the one with the highest priority.

### Introducing our test element

A priority queue should work with any type of element, not just numbers. As long as there is a way to determine their priority, we should be able use them.  
I created this `Element` class, which has a `name` and a `priority`, just so we can use in our tests:

```ruby
class Element
  include Comparable

  attr_accessor :name, :priority

  def initialize(name, priority)
    @name, @priority = name, priority
  end

  def <=>(other)
    return 1 if @priority > other.priority
    return -1 if @priority < other.priority
    return 0
  end
end
```

It includes the `Comparable` module and implements `<=>`, so we can sort a list of `Element`s.

### The naive implementation

Let's start with a very simple (and naive) implementation of a priority queue. The idea is that, every time that we need to remove an item, we will sort
the entire list of elements by their priority, and then we can just return the last element, that will be the one with the highest priority:

```ruby
class NaivePriorityQueue
  def initialize
    @elements = []
  end

  def <<(element)
    @elements << element
  end

  def pop
    last_element_index = @elements.size - 1
    @elements.sort!
    @elements.delete_at(last_element_index)
  end
end
```

And we can check that it works:

```ruby
q = NaivePriorityQueue.new
q << Element.new("bar", 1)
q << Element.new("foo", 3)
q << Element.new("baz", 2)

p q.pop.name # => "foo"
```

The problem with this approach is the performance, as you might have imagined. Although we can insert in constant time (`O(1)`), the removal is linear (`O(N)`), meaning that
the operation time will grow linearly and in direct proportion to the size of the `elements` list. As the size of the list doubles, the time to perform the operation also
is expected to double.  
We can do better.

### The binary heap

The most common data structure used to implement a priority queue is the binary heap, that is basically a binary tree with some additional properties.
The binary heap is a **complete binary tree**, meaning that it's fully balanced, or, in other words, that all the levels of the tree a filled with elements, except possibly for the
last level of the tree.

<img src="/assets/images/binary_tree.svg">
<div class="image-description">
*Example of a complete binary tree*
</div>

The other thing that distinguishes a binary heap is that it comply with the **heap property**, meaning that all the nodes are greater (or equal) than their children.
<img src="/assets/images/heap.svg">
<div class="image-description">
*Example of a binary heap. Notice that it's a fully balanced binary tree, where all the nodes are greater than their children*
</div>

One thing that is very interesting about binary heaps is that they can be represented as a simple array. There is no need for links or any complex data structure, just a
simple array. If you think about, it makes a lot of sense. The children of an element at a given index `i` will always be in `2i` and `2i + 1`. The same way, the parent
of this node will be at the index `i / 2`.

```ruby
# 0  1    2   3   4   5  6   7  8  9
 [0, 100, 19, 36, 17, 3, 25, 1, 2, 7]
```

This array represents the tree in the previous image. For instance, if you get the element at the index 4 (`17`), you can check that its parent is at the index 2 (`19`), and
that its children are at 8 (`2`) and 9 (`7`). The only caveat here is that we add a `0` in the first position of this array, that will never be used, but make our
calculations a bit easier.  
You can find the nodes relation by doing simple arithmetic on their indexes. How cool is that?

### Implementing a real priority queue

After we understand how a binary heap works, it's easy to see how it can be used to implement a priority queue. The element with highest priority will always be in the root
of our tree. When we add elements to this queue, we just need to make sure it is placed in the right place to comply with the heap property.

##### Adding items to the queue

First we will just append the item to our array:

```ruby
class PriorityQueue
  def initialize
    @elements = [nil]
  end

  def <<(element)
    @elements << element
  end
end
```

Just by doing this we already have a complete tree. The problem is that it violates the heap property. We need to make sure it is in the right place of the tree,
meaning it is greater than its children, and smaller than its parent. This operation of putting a node in its place has many names, the most common being `bubble up` or
`heapify up`. So let's implement it:

```ruby
def bubble_up(index)
  parent_index = (index / 2)

  # return if we reach the root element
  return if index <= 1

  # or if the parent is already greater than the child
  return if @elements[parent_index] >= @elements[index]

  # otherwise we exchange the child with the parent
  exchange(index, parent_index)

  # and keep bubbling up
  bubble_up(parent_index)
end

def exchange(source, target)
  @elements[source], @elements[target] = @elements[target], @elements[source]
end
```

Now we just need to call it after we add a new element:

```ruby
def <<(element)
  @elements << element
  # bubble up the last element
  bubble_up(@element.size - 1)
end
```
