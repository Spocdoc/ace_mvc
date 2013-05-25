# Cascade

  - raw functions that are added as outflows of (deep) multiple cascades are invoked multiple times

    fixing would require changing the implementation to store pending states in a closure, rather than on the objects themselves

    the same could be done with inflows and outflows so the function wouldn't have properties added to it

    another alternative is to just make such functions autoruns

  - this has a very inelegant hack (the @calculating + @pending business)

    instead, it should calculate if an inflow is also an outflow and it has priority by looking at an index number that's set sequentially for each cascade when the outflows are set to pending. this would require doing a breadth-first traversal...

# Outlet

  - optimization: should cache the change to function mapping instead of looping through all the functions (map from change cid to function)

# HistoryOutlet

  - if you call `noInherit` after `ensurePath`, which creates an inherited object, then call `noInherit` on that object, it does nothing because the object is own property (despite inheriting)

        // initially, all of foo is inherited
        noInherit ['foo','bar'] // undefines foo.bar locally
        noInherit ['foo'] // will do nothing

  - the implementation doesn't allow keys and paths to be the same -- you can't have ['foo','bar'] as a key and ['foo','bar','baz'] as a key because the latter requires ['foo','bar'] to be a Compound

    this is not just inconvenient, it's inconsistent with what's done with outlets in the model

# Navigator

  - when navigating away from the entire site then back to some point in the middle of the site's navigation history, all the data structures have to be restored based on the URL alone. The current implementation resets the index to 0 at the entry point. When you navigate around, the previous induces are overwritten with the new ones, so they're out of sync with the actual order in the browser. This means when `navigate()` is done to a new URL and the array is sliced, data that's still accessible gets cleared.

    The upshot is unnecessary reloading of content that's been erroneously erased. 

    The solution is to use the index as it appears in the push state or hash, rather than overriding it. This means the inheritance in HistoryOutlets has to be more flexible: you may start at index 2 then jump to index 0, so now index 0 inherits from 2.

  - when using hash, there's a flash of the index page followed by loading the target page

  - should "debounce" the calls to replace and ensure that if a push call happens, any pending replace is invoked immediately, the timer reset and then the push called

# Template

  - it'd be nice to have a more elegant implementation of the constructor. the TemplateBase could be a Factory 

# Socket.io

  - unreliable XHR with cluster

    will sometimes drop large numbers of initial messages when the connection is established



# Model

  - currently doesn't detach outflows on navigate so, (1) it leaks and (2) invisible views are being updated when off screen (preventing transitions, etc. when there are updates to previous pages)

  - It's currently grossly inefficient for outlets that refer to documents or arrays: the referenced part of the document is (deep) cloned any time a piece of it changes.

    this can be optimized by adding a `changed` method to outlets
# Server-side rendering

  - currently doesn't wait for async outlets to finish

  - requires all the templates, views and controllers to be loaded in memory up front. would prefer this to be done on demand (which also means asynchronously...)

    this could be done with a proxy function for every possible page added to Template, Controller and View.

    this can also address the missing controller problem -- where the view or template is specified but the controller isn't.

# Client-side rendering

  - when requesting a URL with a hash, the server won't see the hash and will send a different page. the client does nothing about this discrepancy

# View

  - doesn't allow swapping out the template

    this is very bad for serving static files. since the controller's view is immutable, if the template of the view is also immutable it means creating a new view and controller for every static file...

# Ace

  - the layout can't have a doctype or the template renderer puts it in a div container

# Bundle

  - it sends the compiled script with `res.end(script)`

    there may be a more efficient way? of course in prod the whole thing should be on a CDN...

# closurify
## exports

  - closure doesn't work as well if all the module variables are first set to `{}` then overwritten. It does more aggressive inlining if they're not initially defined. This means that statements like this

        exports.foo = 'bar';

    will result in an error since the exports variable won't have been declared. For the time being, it'll have to be

        module.exports = { foo: 'bar' };

## require

  - doesn't detect use as a function

    e.g.,

        var a = require('./foo')();

## `__dirname` and `__filename`

  - neither of these is available

