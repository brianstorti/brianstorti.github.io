---
layout: post
title: Designing good APIs - Avoiding the type marshalling trap
intro: Automatically serializing a model object in a data format may be tempting, as most frameworks give this functionality out of the box, but it can bring more problems than benefits.
meta: Automatically serializing a model object in a data format may be tempting, as most frameworks give this functionality out of the box, but it can bring more problems than benefits.
---


"Type marshalling" means automatically serializing an internal object (`order`, `product`, `address`) in a data format (`json`, `xml`, `html`)
that is returned to the consuming client.

It's tempting to use this technique, as most of the popular web frameworks give this functionality out of the box.

If you use Rails, even the scaffold generated code does this for you:

```ruby
def show
  @product = Product.find(params[:id])
 
  respond_to do |format|
    format.json { render json: @product }
  end
end
```

Or, if you are using Spring MVC, just by adding a **@ResponseBody** annotation in your controller method you will have a serialized user object:

```java
@RequestMapping(value = "/product/{id}")
@ResponseBody
public Product show(@PathVariable("id") String id) {
    return Product.find(id);
}
```

This would generate a response with a json like that:

```json
{
  "product": {
    "name": "Marled wool cardigan",
    "size": {
      "code": "0002",
      "variantName": "Regular",
      "variantId": 1,
      "dimensionOne": "M",
      "regular": true,
      "dimensionTwo": null
    },
    "price": {
      "type": 6,
      "current": {
        "amount": 27.97
      },
      "regular": {
        "amount": 29.00
      },
      "deprecated": {
        "amount": 0
      },
      "deprecatedType": 0
    },
    "businessId": "2285370120002",
    "taxCode": "C1",
    "priceType": 0,
    "images": {
      "imagePath": "webcontent/0005/537/723/cn5537723.jpg",
      "thumbnailPath": "webcontent/0005/537/721/cn5537721.jpg"
    },
    "returnCode": null
  }
}
```

This was pretty easy, with a few lines of code we already have an API that can be consumed by our clients. So, what's so bad about this?

Well, there are a few problems with this approach, but I want to talk specifically about one, that, in my opinion, is the most critical.


## Coupling your server to your clients

This approach is very server-centric: A small change in the server might break its clients. That's definitely not what we want for our APIs.

Refactoring an internal behaviour shouldn't require changes in the clients. Imagine having to publish a new version of your API every time
you want to rename a field. You don't want your clients to have this knowledge of your internal structure, it kills your ability to change.

Besides that, it just make it harder for the client to use this response. Why should it care about a "businessId"?
And if it wants to show the product price, it needs to know that a product has a "price" field, that has a "current" field, that has an "amount" field. That's way too much.



## The solution: Build you own responses

If we don't want to expose our internal data structures to the outside world, one approach we can take is simply building our own response object, or, in other words,
define this resource's  representation.

A representation is nothing more then a description of the current state of our resource, and that's exactly what we will build.
There is probably dozens of ways to implement this, and I'll just show one of them, that is the most simple implementation I can think of.

```ruby
class ProductRepresentation
  def initialize(product)
    @price = product.current_Price
    @name = product.description
    @size = product.size_name
    @image_path = product.image_path
  end
end
 
class ProductsController < ApplicationController
  def show
    @product = Product.find(params[:id])
    render json: ProductRepresentation.new(@product)
  end
end
```

And with this code, we have a much smaller response, that does not expose our internal structure:

```json
{
  "name": "Marled wool cardigan",
  "price": 27.97,
  "size": "Regular",
  "image_path": "webcontent/0005/537/723/cn5537723.jpg"
}
```

If anything needs to be changed in the server, we just need to make sure
that the `ProductRepresentation` is still getting the correct data in the correct fields and all of our clients will continue to work.

## Conclusion

As always, this is not the best approach for all the cases, if you have a very small API dealing with simple data structures, or if you have just one client in a very controlled environment, it might not
be worth to have this extra work of building your responses.

Even in these cases, though, I think it's a nice exercise to think how coupled is your server to your client, and what would be the
impact of minimizing this coupling, allowing both server and client to grow and evolve as independently as possible.
