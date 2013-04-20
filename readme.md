# High-level features

  - server-side rendering
  - client-side bootstrap from server render
  - push-state/hash navigation
      - memory management
      - navigating preserves states
  - auto-updating dependencies
  - live data sources
  - queriable local collections
  - routing with slugs
      - `link_to(model)`-type functions

# Design problems

  - `link_to`

      - requires the caller (would have to be a controller) has access to the model itself

      - may require details about the model that aren't available locally (e.g., author's username, article slug)

  - how to generate queries

      1. look 

# HistoryState (HS)

# Server-side DOM manipulation

Uses Cheerio to manipulate fragments from templates, build a page the same way it's constructed on the client, then send it

# Templates

Templates are stored in a `Template` variable by name, e.g.

    Template['EditableCell']

The template consists of a root element and $ references to elements in the template source that have ids.





# Client-side bootstrap from server render

  - inlined `<script>` after the body includes all the models

    this script is immediately after an external include

  - links have regular href and an `onclick` that's in the HTML itself. 

    the `onclick` goes to a function that's inlined in a `<script>` in the HEAD, overwritten by the external script

So structure is

    <html>
      <head>
        <script>
            // some onclick function that's overridden by the included script
            var Ace = {
              navigate: function () {}
            };
        </script>
      </head>
      <body>
        <a href="/mikerobe/some_post" onclick="Ace.navigate(event)">post</a>
      </body>
      <script src="main external script"></script> 
      <script>
        // generated script loading all the models, etc.
      </script>
    </html>

Server stores serialized state in the HistoryState so the views, controllers, etc. can retrieve it. This data must be JSON-serializable (no functions, no references to other objects -- just data).

When the views are constructed, before they clone any templates, they look at the document DOM to see if an element with the right `id` is present. If so, they bind to that and restore the memoized values of all their outlets. This way, when the outlets are bound to inflows, if those inflows have identical values, the outflows aren't called (so the DOM isn't re-rendered).



# auto-updating dependencies

Rather than using terms "dependent" and "dependency" (which I find confusing because they're so similar) the terms are _outflows_ and _inflows_. Outflows are calculations that depend on this one. Inflows are calculations or values on which this depends.

Ordinary dependency tracking works by keeping track only of the outflows of a calculation or value: when the value is set, all its outflow functions are called again (not immediately -- the whole tree of outflows is marked as "pending" then the whole tree is called).

Add an outflow to an object with

    target.outflow(func)

When `target` changes, it sets `func.pending` then calls `func()`

a Cascade is a function that when executed sets itself and all its outflows as "pending" then, at the end of the block (which could be the end of the function), runs itself and its outflows

## cascade

    var a = new Cascade(function () {
        // this function is run when any inflow changes
        // and afterwards, all the outflows are called
    });

    // a hash from function cid to function
    a.outflows

    // deleting an outflow
    a.outflows.remove(func);
    delete a.outflows[func.cid];

    // adding an outflow
    a.outflow(func);
    a.outflows[func.cid] = func;

Every `Cascade` stores *both* inflows and outflows. This is required for the calculation algorithm. But this is bookkeeping done by the Cascade object. When outflows are added, if the outflow itself has an `inflows` hash, `this` is added to it

## outlets

    var a = new Outlet();

    // set
    a(42)

    // get
    console.log("a is " + a());

    // when a is updated, b is set and vice versa
    var b = new Outlet();
    a(b);

    // adding
    a.outflow(function () {
        console.log("A updated to " + a());
    });

    var c = function () {
        return "some value";
    };

    // when a's cascade is called, it sets a's value to c()
    a(c);

When given a function, outlets track any calls to other outlet's getters and add them as inflows


## outlet methods

Views & controllers have outlet methods -- methods 

outlet methods:

    var x = new Outlet(1);
    var y = new Outlet(2);
    var foo = function (a, b) {
    };

    // optional context
    foo = new OutletMethod(this, foo, {a: x, b: y})

    foo.rebind({a: y, b: x})

equivalent to

    foo = new Autorun(function () {
        originalFoo(x.get(), y.get());
    });

except that detaching also removes references to x and y (so when they change, the value doesn't change)

  1. extract the function argument names
  1. store the names to an array
  1. store an array of outlets corresponding to the arguments
  1. on invocation, `apply` the function with this array


## autorun

Whenever an Autorun is `run()`, it tracks all the calls to `get()` for Outlets and adds them as inflows.

An Autorun object is a Cascade


## blocks & calculation method

When a `cascade()` is fired, it immediately runs the following algorithm:

  1. call `pending(true)`

    this recursively sets the `pending` flag for all the outflows

  1. if `Cascade.roots` is *not* set, call `calculate()`

    else, add this `Cascade` to the root hash by cid

`calculate()`:

  1. return if any of these requirements are not met:

      - pending
      - all pending inflows are also outflows

  1. run the function

  1. set `pending(false)` (which does not need to recurse)

  1. call `calculate()` for each outflow

A `Cascade.Block` creates a `Cascade.root` if it doesn't already exist, executes the passed function (which may itself invoke cascades), then *if it created the `Cascade.root`*, calls `calculate()` on all the roots.

`Cascade.Block` can be executed immediately:

    Cascade.Block(function () {
        // ...
    });

or stored as an object that can be run later

    var block = new Cascade.Block(function () {
        // ...
    });

    // invoke
    block();



----


Because support is required for ES3, instead of wrapping a value and modifying its `get` and `set`, the library wraps *functions* that when called with no args return the underlying value and when called with args set it. 

    // regular "variable"
    var foo = (function () {
        var value = 42;
        return function () {
            if (arguments.length == 0) {
                return value;
            }
            value = arguments[0];
            return value;
        };
    });

    // wrapping the variable for dependencies
    foo = new Outlet(foo);

    foo = new Cascade(42);
    foo.outflow(bar);

    // sets 
    foo(bar);

    bar = function () {
    }


    var Outlet = function () {

        // store inflow

    }



## updating process

The whole update is synchronous -- no timeouts are involved. 



# data sources, queries & local collections

  - models/queries have these flags:

        live            means it *may* subscribe to server updates
        subscribeCount  if live is true and subscribeCount > 0, then server sends updates

    when controllers detach from a model, they remove their dependencies on the model's fields. The model tracks the total number outflows 

  - queries are always documents

# push-state/hash navigation

## memory

  - controllers/views have to detach any connections to models or queries

# local queries

queries can be done locally if one of these is true:

  - query is on the full collection

    then a query document is formed 

  - query is a subset of an existing query


