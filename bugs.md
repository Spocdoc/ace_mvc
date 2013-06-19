# Cascade

  - raw functions that are added as outflows of (deep) multiple cascades are invoked multiple times

    fixing would require changing the implementation to store pending states in a closure, rather than on the objects themselves

    the same could be done with inflows and outflows so the function wouldn't have properties added to it

    another alternative is to just make such functions autoruns

  - this has a very inelegant hack (the @calculating + @pending business)

    instead, it should calculate if an inflow is also an outflow and it has priority by looking at an index number that's set sequentially for each cascade when the outflows are set to pending. this would require doing a breadth-first traversal...

  - OutletMethod has some inefficiency when it sets itself to another outlet when the function returns an outlet: it causes the outlet it's set to to re-run (setting all of its outflows to pending) then stop propagation (setting them back to not pending) unnecessarily

    this isn't easily avoided. after running the function, cascade() is called, which sets the outflows to pending

  - in principle if a set of outlets are all equal to each other and one is set to a function that's going to be recalculated, you shouldn't be able to explicitly set any of the outlets that flow to the outlet with the function because that function will run and override the value. Currently, it'll only override the value for *some* of its outflows, not including the ones that were explicitly set later. This means there's an inconsistent state: a set of outlets that are supposed to be equal to each other are now not equal.

    This is because it isn't just an individual outlet that can only logically have 1 function, it's the entire equivalence set. Whenever an outlet is `set()`, if it's currently pending and is pending because it's the outflow of a function that will be calculated (because either it's been run or one of its auto inflows has changed), setting that outlet shouldn't be permitted (but should it raise an error?)

  - OutletMethods that both retrieve a value and set it always run twice...

  - this feature of aborting a calculation when a pending outlet is fetched would be useful to have on regular methods in the mvc, not just outlet methods. 

    a function would have to temporarily add itself as an outflow of the pending outlet, then remove itself once it calculated

    this could create problems if functions are run repeatedly and have side-effects before the abort

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

  - XHR polling doesn't work at all in IE6

  - htmlfile doesn't allow client response or client-instigated requests, just server emit

    it receives a huge block periodically instead of getting a stream of data from the client:



# Model

  - currently doesn't detach outflows on navigate so, (1) it leaks and (2) invisible views are being updated when off screen (preventing transitions, etc. when there are updates to previous pages)

  - It's currently grossly inefficient for outlets that refer to documents or arrays: the referenced part of the document is (deep) cloned any time a piece of it changes.

    this can be optimized by adding a `changed` method to outlets

  - the model (wrapping the doc) will always have the wrong version number

    this is confusing but doesn't cause errors because the client never sends version updates to the server and the model client has no transparency into the versioning

  - there's no way to tell when/if a particular update has succeeded. you instead have to subscribe for the reject event then check if the doc is now inconsistent with the update you tried to apply. this is not great. the doc could have been rejected because of an earlier pending update

  - if an outlet is set to an object and another outlet is set to a part of that object, client-side updates to the outer object don't update the inner object

    could be fixed by adding patchOutlets to the _pusher outflow...

  - it would be nice to be able to make calls like

        @ace.session.get('user.username')
        @ace.session.get('user.priv.password')

    instead of

        @ace.session.get('user').get('username')
        @ace.session.get('user').get('priv')?.get('password')

    this introduces some complexity when patching outlets. the original model has to create its own outlets and set them to the other model's outlets, then when the DBRef changes, unset them and set again to the new model's outlets


# Server-side rendering

  - currently doesn't wait for async outlets to finish

  - requires all the templates, views and controllers to be loaded in memory up front. would prefer this to be done on demand (which also means asynchronously...)

    this could be done with a proxy function for every possible page added to Template, Controller and View.

    this can also address the missing controller problem -- where the view or template is specified but the controller isn't.

  - cheerio doesn't have the css function

    the simple workaround I added doesn't accommodate values with semicolons

# Client-side rendering

  - when requesting a URL with a hash, the server won't see the hash and will send a different page. the client does nothing about this discrepancy

  - the session is being created in routes, but ace is hooked into the DOM *before* the routes are run, so if a link is clicked after hooking but before routes are setup, there's no session variable --> error.

# View

  - doesn't allow swapping out the template

    this is very bad for serving static files. since the controller's view is immutable, if the template of the view is also immutable it means creating a new view and controller for every static file...

# Ace

  - the layout can't have a doctype or the template renderer puts it in a div container

# Bundle

  - it sends the compiled script with `res.end(script)`

    there may be a more efficient way? of course in prod the whole thing should be on a CDN...

# Closurify
## exports

  - closure doesn't work as well if all the module variables are first set to `{}` then overwritten. It does more aggressive inlining if they're not initially defined. This means that statements like this

        exports.foo = 'bar';

    will result in an error since the exports variable won't have been declared. For the time being, it'll have to be

        module.exports = { foo: 'bar' };

## require

  - the drop-in replacement can lead to empty statements like

        ...
        __1
        ...

    that in closure may be distilled to

        ...
        void 0
        ...

    if the whole variable is removed, which is invalid code. This is really a closure bug, but it would be preferable to issue a warning and remove the expression from both the debug and pre-closure code

## `__dirname` and `__filename`

  - neither of these is available

## source maps

  - shouldn't use the same file name for the CoffeeScript input and output (this makes the sourcemap useless)

    instead have to have a temporary .js name for each file

    UPDATE: this seems to work now?



# Server replies

  - the ace server reads all its configuration files asynchronously and doesn't prevent the http server from trying to serve requests before it's added itself (so clients get 404 until the server is up)

    preferably it should not open the server until everything is ready to serve requests (especially since it could be part of a cluster)
# Statelets

  - if the value is the same from one page to another, the dom won't be updated (because the cascade leading to the statelet sees an identical value and stops propagating updates)

# Browser compatibility

  - want conditional loading. there's at least 3k of code that's completely unnecessary on modern browsers there to support IE<8


# Optimization

  - may want to reduce the number of outlets/outlet methods

    instead of creating new outlet methods in the controllers/views, could assign the functions directly to the ToHistoryOutlet

  - every method for view/controllers has to run in a cascade block

    the implementation is inefficient:

          @[k] = (args...) =>
            Cascade.Block =>
              m.apply this, args

  - because to_mongo doesn't work with a sequence of overlapping changes, the server has to recompute the diff for every update...

  - should use cache control and etags for production script and inline the CSS

  - currently the DOM gets set twice whenever a DOM-writing outlet is set to a non-HO outlet: once on the server render and then again by the client

    this is because these outlets aren't being persisted and so their value isn't restored when the page is restored on the client

    the best solution is to restore the DOM cache somehow in each view that whose template is bootstrapped from the page

  - sessions don't currently expire out of the database. there will have to be a mechanism for removing them

  - does socket.io when using the redisstore lead to memory leaks if the application crashes?

# Error handling

  - there should be better error handling on the client side

    e.g., when there's an error creating a session.

# security

  - the socket message parsing and diff parsing need to be robust to arbitrary messages

  - the diff is not secure

    it assumes the messages are consistent. doesn't check for operations > 1 and is inconsistent about checking for 'd' vs checking o['o'] is 0

  - the person's password is sitting in a document the whole time they're logged in

    also, when they log out, it should clear the whole database

# diff

  - extractField and hasField are for top level fields only -- they don't work for nested fields

    (supporting array indices may be complex)

  - it may be a good idea to remove the possibility of keyless diffs. this would tremendously simplify (and eliminate) some of the code

    this may also be critical for security -- checking for fields could be hacked by sending a bunch of top level diffs
# database

  - to_mongo doesn't accommodate a set of updates that overlaps (e.g., an increment followed by a set or a set then unset)

# Ace

  - there's a lack of proper separation of concerns with the model and ace

    findModel, deleteModel, etc. all use details about the database setup that would be better left encapsulated in the Model class

  - the ace.reset() method could be revisited

    currently it calls location.reload() and is overridden in the server-side render


