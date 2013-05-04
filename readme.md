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

# HistoryData (HD)

# Server-side DOM manipulation

Uses Cheerio to manipulate fragments from templates, build a page the same way it's constructed on the client, then send it

# Templates

Templates are stored in a `Template` variable by name, e.g.

    Template['EditableCell']

The template consists of a root element and $ references to elements in the template source that have ids.

Every template has a `$root` element. When the template is assigned to HTML, if there are multiple top level elements, everything is wrapped in a `div` and the `div` is assigned to `$root`.


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


  1. script reconstructs all the collections (models, queries)

    does this using data stored inline

    (the models can't subscribe to server updates yet because nothing's linked to their outlets)

  2. script stores all the history data into the HistoryData structure at index 0, setting the `to` to 0 and `from` to `undefined`

    this is a mapping from view/controller CID to JSON data

    this state includes the values of all the outlets, so these are restored before the outlet is hooked to any inputs

    this CID is the same as the `id` on root elements in the DOM (child elements are prefixed with this id, e.g., `fooview-main` instead of `main`)

    these CIDs can't be numbered sequentially because the client could instantiate them in a different order than the server. 

    data sources, views, controllers, etc. are all looked up lazily. when they're instantiated, they look at the HistoryData for state to restore

  3. script calls `navigate()` on the router

## CID scheme

  - data sources have cid `<collection>-<_id>` and are looked up and bound by the controller lazily on demand

  - every view is referenced by a controller by a name and every controller is referenced by some other controller by a name except the top level controller, which itself be given a name by the router

    This sequence of names forms a "path" that uniquely identifies the view or controller for a particular history index

    Because `id` fields can't have `/` and `:` is problematic for jQuery, `-` is used to separate path components

    names are all camel case starting lower case

    The top level controller is identified with the name `ace`

    e.g., a view may have the id `ace-tags-view` where tags is a `Cells` controller. The `ace-tags-view` view gets cell views from the `ace-tags` controller, which are named by their index in the view pool

Views and controllers have to be told their name so views know what to look for in the DOM. Because views may be reused with different names (e.g., in the Cells controller's `cells[]` pool), the `cid` property is also mutable. Changing the name updates the `id` fields for all the identified elements (e.g., if you change a controller's name, it changes all of its views and referenced controllers; if you change a view's name, it changes all the DOM `id` attributes, including its root)

Each of the template `id`'s that a view binds to is re-assigned an `id` using the name of the view. e.g., `ace-tags-view-detail`

For pools and collections, `cells(0)` becomes `cells_0`, e.g., `ace-tags-cells_0`

TIP: the "name" property is called `cid`, not `name` to avoid conflicts and to be consistent with how functions, outlets, etc. are named. Outlets have their own scheme for assigning `cid`'s. Views, Controllers, Models and HistoryData don't care about this: it's transient and outlet and outlet method `serializedValue`'s are stored and restored by name 

## outlet reconstruction

  1. `a = new OutletMethod(func)` where `func = function (b)`

    build the outlet methods but ensure they're not bound yet

  1. `a.restoreValue(HD[<id>-state].outletMethods['a'])` if such a value exists

  1. `b = new Outlet`

    construct the outlets with no initial value

  1. `b.restoreValue(...)` if such a value exists

    this is not as important. could just initialize with the value, since it has no outflows

  1. `a.rebind(b: outlets['b'])`

    bind the outlet method to the outlet. this won't call the function because the values of the outlet method's inflows are the same as the current (restored) value

  1. `b.set(val)`

    set the value of the outlets based on the constructor arguments (e.g., `main: model.main` or `main: -> model.fname.get() + model.lname.get()`)

# navigation

There's a router with a collection of routes

on the server side, these routes are all added with `app.use`. A function is called that creates a Cheerio DOM using a simple page layout (`$ = cheerio.load layout()`) containing the scaffolding for the server

There is a single _top level controller_ called `ace` (or whatever name it's given on instantiation)

This top level controller has a root view called `root` (so its `id` is `ace-root`). That view uses the top level controller as a delegate to get other views for whatever its layout is.

Every route has an associated route name, e.g., `"articleView"`

`HistoryData` has `to` and `from` fields 

A controller has this information:

  - views
  - other controllers
  - data sources (models)

it also has

  - map from route name to the views that should be shown or removed
  - `navigate()` method

    can use the `HD.to` and `HD.from` fields to set variables, etc. that change the view

  - `appendTo($dom)` method

    adds the appropriate views given

  - `remove()` method

    removes the current views (how does it know if it should remove the `to` or `from` views?) from the DOM

Controllers always have a primary view called `root`, which can't be changed. If you want to completely change the layout of a page, the top level controller must have a view consisting only of a box whose content is filled with a delegated controller. 

Views also have a `root` property, which is cyclical. This allows calling `x.root.y()` where x is either a controller or view and `y` is assured to refer to a view method. (e.g., when a view delegates to a controller to give it other "views", these "views" may actually be controllers, so the view calls `view.root.appendTo(...)` to do insertions)

The page is initialized by constructing the top level controller and appending it to the body:

    // first, setup HD

    // this builds the controller, which sees the current route and constructs
    // the necessary views/controllers, each of which restores its state from
    // HD and sets the DOM elements either to a new clone of the corresponding
    // Template or to the document itself (which it finds by calling `$('#<cid>')`)
    root = new Controller['root']({cid: "ace"});

    // no-op if the root's view is already in the body
    root.appendTo($('body'));

There are 2 ways a controller can navigate:

  1. swap out a delegated controller or view

    e.g., the content pane of a layout could be substituted with an article reader or a search list. This could be done with a view method (`replaceContent()`) or the view could have an outlet that should be set to a view/controller and have a listener method that calls `remove()` on the old and `appendTo` on the new

    here, the `remove()` and `appendTo()` calls automatically cause the view/controller to save any volatile state that won't be retained when its DOM is extracted from the page. `remove()` on a controller calls the controller's `root`'s `remove()` (which saves its state and extracts it from the DOM) but first calls `saveState` on every other view or controller the controller manages



  2. swap out the data source(s) for a view

    e.g., the same reader view may be used, but its outlets may be bound to a different source or the controller could call a view's method (e.g., `resetData()`) and give it new inputs in response to delegate calls

    This requires the controller to manually save and restore the view's state

Whenever new views and controllers are constructed, they're put in the HD `to` index

Navigating to a new page is treated identically to navigating to a previously seen page because state is always restored if present and views/controllers are constructed lazily on demand

options:

  - save state takes an index and stores there, if the index is the `from` value, then `to` is set to undefined

  - remove() saves to the from index and sets the to index to undefined 

  - require that any identically named view has its data substituted

    e.g., if a controller has a delegate called `articleReader`, there's only one of those. when it's used to read another article, it can't ever instantiate a new one and instead substitutes the data. if it wanted multiple copies, it would have to have distinct names: `articleReader_<article id>`

    this could remove duplication when the DOM is identical because the same data is being sourced and would prevent having to re-render, e.g., markdown data into HTML

    it also allows that when you remove the view, it can always insert `undefined` safely in the `to` state variable

    This would make searches difficult. With search results, you want to re-use the same results controller while the search is being changed on the fly, but then want to use a new results controller when a new search is performed (so the old results are saved in a document fragment instead of being re-rendered). Supporting that would require changing the cid of the results controller just before it's removed. The name change would have to propagate all the controller's delegate controllers and views down to every element in the tree with an `id`. An alternative is to split the names -- there's a cid used in the DOM id's and a cid used to fetch the HD variables

  - allow identically named views to refer to different view instantiation

  - calling remove() on a view will

    - set the view's cid in the `to` HD to `undefined` iff `to` doesn't already have a field
    - set the view's 

  - remove takes a bool called `preventReuse` that, if true, inserts `undefined` to the `to` field for the view or controller (iff doesn't already exist)

    calling `remove(true)` will mean constructing a new instance of that view/controller whenever it is needed again (except when navigating back to where it was originally used before it was removed)

    e.g., top level controller may remove(true) the search results controller, but remove(false) the article reader because the article reader can just have its data (the article id) substituted. This way the search view doesn't have to store a bunch of state

    if a controller expects to have its delegates replaced (e.g., a delegate search results controller), but it is itself reused, it could be navigated to where it doesn't handle the `from` state and has a current `to` that it does handle

    the same problem arises with state for views. 

    thus when a controller is `remove`'d, it has to propagate some kind of removal event to all its delegate controllers and views telling them to save the current state, set an `undefined` to the `to` (iff doesn't currently exist) and possibly set an `undefined` on their own key if it's a `remove(true)`-type of controller

    if something is `remove(true)`'d, all of its delegate controllers and views have their values set to `undefined` in `to`

    regardless of the type of removal, state is always stored as if it were remove(true). 


What is "state"?

  - could include outlet values if initially set from the server
  - if the controllers/views are being reused, state is anything that shouldn't be reused
  - includes transient data not preserved in the DOM (scroll positions, selection)

The state could consist *exclusively* of outlet values. But there will have to be a different kind of outlet that's re-run every time its value is fetched

Scroll position could be one of these "permanently dirty" outlets. Whenever its `get()` is called, it calculates a function 

What happens if a controller is removed and it isn't part of the navigation? If it weren't treated separately, the current state of the thing would be saved to `from`

Instead of calling it `remove()`, then, call it `archive()`.

The view and the dom it points to are tightly bound. You can't extract or change the dom the view wraps. The dom the view wraps is determined when the view is constructed

questions: 

  - if all you're doing is setting a bunch of outlets, how do you ensure things happen in a particular order?

    that's the job of `appendTo`

    the view does some construction before it sets any outlets using the constructor args:

      - setting the cid (which the view getter does)
      - cloning the template or binding to the dom

    the view can have closure variables that aren't in outlets

  - constructing by updating a bunch of outlets simultaneously could lead to strange behavior

    e.g., setting both `delegate` and `numRows` in a table view would cause all the rows to be drawn, then the view to be reset (releasing all the rows), then the view to be drawn again

    one solution: create the `OutletMethod`'s and have them set flags that are outlets in the closure. Then create another `OutletMethod` in the closure that depends on those flags. It will be called after all the flags have been set. example flags:

      - change offset
      - change n
      - change delegate

    then it has logic: if change delegate do a reset and redraw, else ( if change offset, ...)

  - how do you give default values to the view outlets?

    separate `outletDefaults` argument:

        extraOutlets: ['foo', 'bar'], 
        outletDefaults: { foo: 0, bar: '' },
        outletMethods: [ function (foo, bar) {} ]

    or

        extraOutlets: { foo: new Outlet(0), bar: new Outlet('') }

    or just add with

        this.outlets.foo = new Outlet(0);

  - how do these "dirty outlets" work?

    beforeNavigate event

UNANSWERED QUESTIONS:

  - how do controllers that are no-reuse allow for variable changes to their own variables that are route-inducing?

    there's an abstraction layer before the controller/view itself is updated. this abstraction 

  - how does the view add event listeners to the dom?

    there's a standard `dom` outlet. when the view is first constructed, this is one of the outlets that changes

    this allows, e.g., the cells view to look up all of its existing cells when it's bootstrapped from the server HTML

  - if I set an outlet based on an edit made to the dom, how do I prevent the view from changing the dom to its own value?

  - how does the view find out if it's in a window (so it can set the scroll, selection, etc.)?

      - how does it know?
      - how does it get notified?

    could be another standard outlet that could have a 

    adding and removing from a window is an event that causes a view to save state

  - how can the navigation logic be simplified?

    could have the routes store hierarchical data about the nature of the route corresponding to different controllers

    if the top level part of the route changes, the top level controller is updated. if we're still looking at an article, but the article ID changes, something else can listen for that and fire an event...

    each change has an associated type of navigation and a direction (back/forward)

    e.g., navigating from search to article view could be a "top level" navigation. The article reader *isn't* `navigated()` by this. Instead, the top level controller has `navigate()` called (then swaps out controllers, etc.). The article reader controller could get its data from the HD route information -- an article ID parameter

    slugs could be handled by the router *before* any navigation is done, so a resource instance is pointed to in the route on `to` in HD (rather than just `:user` `:article` parameters). this way the routing details aren't relevant for the 

    Each controller

  - how exactly is state "automatically restored"? When you navigate and the same controller is visible, something has to know it's a different instance of that controller or the same controller with different state

    when a controller is replaced: 

      - main controller's `navigate()` `remove(true)`'s the existing search result controller and sets the outlet on the view to `controllers['searchResults']()`

        navigating where the controller is replaced (e.g., search results controller -- which is really just a cells controller -- navigating from one search to another), the `navigate()` function `remove(true)`'s the existing controller (doesn't have to archive because the state is all in the object itself and the view, when it is removed from the window, will store any transient DOM state) then references it. its constructor arguments assign its data to the search results array -- an array of models constructed from a query document, which has an array of model ids. that search results controller takes a cell view type, which it instantiates and hooks to the models in the array

        whenever the search result changes, the search results controller does a diff and calls appropriate functions in the view

      - 

  - how are the outlets detached when a controller is removed?

     removing a controller has to unbind its outlets... otherwise changing the main controller's search data will change its outlet, causing it to reset its view, defeating the point of having removed it

    the models/data sources can unhook 

      - when you remove() a controller, all of its outlets are unbound and the controller's "onremove" function is called

        onremove will detach any view outlets that it previously hooked directly to models

    another option: automatically detach all outlets recursively for all the controllers and views when they are removed. also unset any views and controllers the controllers reference. since they're all identified by cid and stored in HD, when the controller is restored, it can look up the view, which will rebind its outlets. similarly, any data sources are restored based on how they were looked up (e.g., using the value of some other outlet)


  - how do transitions work?

    there's a transition view that has a `to` and `from` delegate (which the controller assigns to other controllers) and other parameters (e.g., slide direction)

    when a navigation event happens, the 


  - how does `navigate()` remove the previous (delegated) controller and replace it with the new one when it has the same name?

    calls

        // this unsets it locally, so when controllers['content']() is called
        // again, it instantiates a new one, which looks for the state in HD.to
        controllers['content']().archive(true)

    (what if controllers['content'] didn't exist before? then it's instantiated with new data and archived to the old spot...)

    that's only if the containing controller handles the from and to routes. if it only handles `to`, then the parent controller (possibly the top level controller) 

`remove()` and `archive()` both have to propagate a save state event to all the views... This has to be done before an element in the window is removed and *not* when an element that isn't in the window is removed (either that or the event has to not be fired on 

Views have a `serializedState()` function that returns a string containing all the outlet values

The *only* event that causes a view to save its state automatically is removal from the window. If a controller is reusing a view, it has to save the state and restore it on `navigate()`.

navigation options:

  - imperative

      - controllers have a `navigate()` function, which

          - archives controller state
          - removes some controllers & calls appendTo on others
          - 

  - declarative

      - describe which controllers are visible for which routes

For building the views, I have *both* options: the declarative approach with a hash of key-values and an imperative approach with a function that configures everything. This makes it very straightforward to configure the base case -- the simple case of a view that substitutes outlets and does simple operations in response to changes. But it also gives the flexibility for more complex behavior (done imperatively).

Approach: stick to the imperative, then figure out how to simplify it with a declarative style

## alternate "draw" approach

instead of thinking in terms of changes, can think in terms of resources

every navigation detaches everything, then calls `draw()` on the top level controller, which calls `remove(true)` where necessary on old controllers, etc. if they exist and sets up the new ones

each route in the controller has an associated collection of controllers, some of which are reused and others not

    [
    {
        routes: [ '*' ], // glob pattern
        controllers: {
            lhs: {
            }
        }
        views: {
            view: {
                type: 'ThreeSplit',
                args: function () {
                }
            }
        }
    },
    {
        routes: ['search'],
        controllers: {
            content: {
                reuse: false,
                from: Controller,
                type: 'SearchResults', // i.e., it's instantiated with new Controller['SearchResults'](args)
                args: function () {
                    // arguments that set the controller's outlets
                    return {
                        delegate: this,
                    };
                }
            }
        }
    },
    {
        routes: ['article#show'], // or could depend on arbitrary parameters in the route
        controllers: {
            content: 
        }
    }

then setup the `view` to point to these controllers:

## variable-driven routing
Meteor does routing by setting a variable and having the things that depend on it update

could set a main route variable, then each route has its own variables

the top level controller has its delegates depend on the main route variable

then the, e.g., article reader swapper controller has its article reader controller delegate depend on the article id.

when the article id changes, everything else is the same (top level controller not involved)

when the path changes from search to article view, the top level controller can swap out the content controller delegate

the *outflows* of these route variables could be detached and remembered (storing them in HD), then routing consists only of restoring the outflows then updating the values. the values could be in HD itself. so navigating to a new page is:

  1. set route values in the new HD index
  2. determine the appropriate destination route variables given the `to` route. the set of these variables should be stored in HD in the `to`
  3. reattach the outflows for these `to` route variables

    for a new page, this will just be the top 
  4. set the value of these destination route variables from the HD index

navigating to an existing route consists of steps 2 through 4

Detaching outflows isn't built into Outlets because the hash it uses to find the right functions has to be in the HD (so that the referenced objects can be garbage collected). Instead, the router patches the Outlet prototype and uses HD.to to do the lookup

If a controller re-uses another, it does this:

    function (routeMainVariable) {
        // this saves any current view outlet values to the HD.from for the view name
        views['view'].archive();

        // this uses the bindings specified in the view config in this
        // controller coupled with the default values for the view to set the
        // view's outlets
        views['view'].restore();
    }

(this could be done automatically if the parameters to the view depend on a route variable directly or indirectly; then if you change a route variable, it constitutes a navigation event -- a new HD is created, future history is erased and anything else depending on that route variable is updated. This could be problematic because you want the route to change first then a `setTimeout(..,0)` before anything is graphically updated to ensure Safari takes a snapshot of the right content. )

When the controller isn't reused (i.e., a new one is built for new routes, like the search results controller), this is done:

    function (routeSearchVariable) {
        // this also removes it
        controllers['searchResults'].archive(true);

        // this looks for an instance
        controllers['searchResults'].restore();
    }

This could also be automated with a flag in the controller specification (`reuse: false`)

NOTE: you don't archive and restore the controller/view itself -- it's `controllers['foo'].archive()` not `controllers['foo'].get().archive()` because otherwise you might instantiate a new one, then archive the new values. So the archive and restore have to be properties of some getter object, not of views and controllers themselves

Unanswered Questions:

  - if the route change is top level, do *all* the destination variables change or just some?

    all the variables are assigned. but not all will necessarily differ from their values at the `to` history point.

    When you navigate to an existing point in history, *something*, even if it's just the top level controller, will be the same for the `from` and `to` points. This will respond to changes in the route variables. The top level controller could have a variable used in the route that determines what the main content is.

    When you make a route-inducing variable change, the 

  - how are all these outlets reassigned when there's a navigation event?

    all the outlets of the views & controllers are 

    when you `remove(true)` something, all of its outlets have to be detached from the `to`. A "straightforward" solution is to use the same inheritance trick again: all the outlets in the `to` also form an inheritance chain and when something is `remove(true)`, the whole block is set to undefined. this way when a new view/controller is created with the same name, you get new outlets, so the old view/controller with the same name doesn't conflict.

  - what if there are no route-inducing variable changes -- or no route variable changes at all -- going from one point in history to another

    you'd still want transient state like scroll position restored

    (1) could click an anchor link that scrolls the page. the browser will take care of push state and pop state and if no variables change, there's no new rendering. Everything's fine.

    (2) you navigate from article 1 to article 2 then click a link to article 1. Thus you have 2 article 1 views at different scroll positions. now you click and hold the back button to go back 2 steps. How is the scroll restored if it's not in the URL?

    There could be route-inducing variable changes that aren't actually shown in the URL -- they're just saved in the HD. Scroll position could be among these. Scroll position could be lazily evaluated

    Routes are just snapshots of outlet values. Changes to some of these outlets induce route changes. Some outlet values to be saved even if they're not changed as part of the route-changing cascade. Whenever you change an outlet value, it needs to be stored directly in the `to` value of the cascade.

    Route changing cascades can be identified as part of the "setPending" phase of the calculation. if a route changing variable is set to pending, the whole cascade is "route changing".

    There's a hook that is called before route changes. Even if there isn't a cascade (because no variables are changed), this hook must be called

  - how do you store the transient dom state?

    Before any route changing cascade, all the registered dirty outlets are re-calculated, if their values have changed, they update the HD (as all the outlets do)

  - how do transitions work?

    suppose you wanted to replicate (properly) the github slide animation for navigating files

    you have an animation controller that delegates `to` and `from` controllers and a transition direction. the `to` is a regular outlet to a controller (e.g., `<prefix>-to`) so its value is determined by HD's `to.<prefix>-to`. It has `reuse: false`. The `from` is set to `HD.from.<prefix>-to`, so it knows the previous controller. Now you have both controllers and a direction.

    when a route-inducing variable change happens (e.g., you click a file name in the `to` controller, which is identified as a route-inducing variable and a variable in the URL), 

  - how do the models get detached?

    a simple rule to follow is nothing is attached to anything outside the scope of HistoryData. Nothing globally can refer to things in HistoryData, but things in HistoryData can refer to global objects.

    So you could have models detach their outflows (just like the route does) each time and keep a list of all the models that are referenced in each HD.

    Alternately, there could be model proxies. ....

    The only pointer going from the model to anything in HD is an outflow from the model outlets (and possibly the model itself) to some of the controller/view outlets. The model could have special outlets that store their outflows in HD. When a route happens, the outflows could be serialized and cleared (set to whatever the inherited values are in the history)

  - is it possible for the views/controllers to archive *themselves* whenever route-inducing variables change one of the view/controller's outlets and would this make for a cleaner solution?

    before any variables are updated, if some flag has been set that this is a cascade from a route-inducing variable change, then call archive and restore before passing any of the changes to the outlets

Answered questions:

  - how will the view know to set its scroll pos to 0 if the it inherits a scroll pos and simultaneously with having that value set its controller has new data from a route?

    this would never happen. you'd always have the data set first or a new view created

    if the value is inherited, it'll be the same as it was before, so the scroll pos won't be set. the data will adjust in the controller

    even if it is set, all the variables are restored in a block, then the cascade is run: the controller data would be set, then its cascade would update the view (which has its own outflow that sets the scroll pos to 0) then the controller calls appendTo. If it's newly being drawn on the screen, it'll never be inserted before the data is reset and the scroll pos consequently set to 0

  - how is the document title set?

    the top level controller's view has an outlet that it can set

  - how is the problem of lockers and archive(true) solved for historical variable lookup?

    you want to be able to replace all of main (set it to undefined) but also allow main.delegate to be replaced while keeping other main.xyz variables

    they're nested by path and pieces are overridden. When a delegate is replaced, its value is set to undefined. When the main is

  - how is that route delay addressed for safari?

    this is not a problem. the document can be modified in the same event loop as push state

  - suppose I'm reusing a table view controller. When I navigate, the view's outlets are restored and the controller's data is restored. Thus the view and the controller change simultaneously. 

    They don't change simultaneously. The only thing depending on the route variable changes -- and that's the data for the controller. 

    Whenever the cascade resulting from a route variable change that is route-inducing causes a change to any of the parameters assigned to 

  - some route variable changes should be pushed and others should replace the current URL. how are the two distinguished and how is it throttled?

    e.g., may want a search that's done as you type to update the URL with replace, not push.

    Also, you may want to ensure that some state is in the URI 

    Could have only some variables instigate routing events, and the others do replace. The variables can change immediately, but whatever outside routine on the client is listening to these routing variables and updating the URI could be "debounced."

    This thing that's listening has a queue of replace-instigating (vs push-instigating) variable changes. When it receives a push-instigating variable change, it immediately invokes all the replace-instigating changes then navigates

    some state -- like selection, but probably *not* scroll positions -- will be passed back into the URL

### new outlets

  - "Dirty" outlets register a function to the `beforeRouting` event, which is fired before a route happens, to call their `run()` so their value is re-computed

  - to and from outlets sync with the named outlets in HistoryData

  - history data outlets 

      - synchronized to an outlet in the controllers/views
      - when set, update an HD value
      - when there's a route event, they're set to an HD value possibly different from the one they update

  - outlets can save and restore their outflows

This means:

  - outlets have a name: a dash-delimited path


### routes

  - route URI

        /:user/:id.:format?

    becomes a regex the server uses to extract variables. The client may also have to do this if doing hash-based routing

    hash -> proper URI -> set variable values -> controllers respond

  - route variables

      - can be "route inducing"  (meaning `pushState` rather than `replaceState`)

      - form a tree under different routes 

Router listens to changes in the route variables sets a global flag that this is a "route event", emits beforeNavigation event before any cascades

The route variables are chosen to correspond to how the page is setup. e.g., there could be a "top level" variable that the top level controller uses to determine what controllers to delegate to. If top level is 

The route variables have to be set when you navigate, so their values have to be in the Snapshots. The route variables are all `ToHistoryOutlet`s that are never replaced (no `noInherit` calls)

Server-side routing:

  - use express to parse params
  - the `function (req,res,next)` builds an Ace instance passing a new document root from Cheerio and the parsed URI params along with the matched "route number"
  - construct the script for the bottom
  - serialize & send the html in the response

Client-side (URI-based) routing: 

  - if URI passed instead of params hash, parse params and search all the routes until one of the parsed regular expressions matches

    if on the server, the regex is the same object used in the express routing

  - translate each parameter to a route variable and update them all in a cascade block

The routes are stored in an array

Two options for transient state (scroll position, focus, etc.)

  1. have a hook on beforeNavigate that re-fetches the information

    may (or not) also want a hook before window removal for cases where it's removed without inducing navigation

  2. have a `scroll` event listener that updates it immediately

    there are timeout issues with this. if the updates are throttled, when the timeout expires the outlet could be set to a different dataStore in history outlets

You'd want to store some of this in the URL -- like selection. If selection is set, scroll position should also be set. Option 1 is better

The route variable outlets have to set a global "routing" flag and emit the event whenever they're set to pending

Components:

  - route outlets that set the routing flag, emit the event and call navigate if the flag is not already set

  - the URI composer that listens to route variable changes, forms a URI and sets the URI HistoryOutlet

    it loops through the array of routes and finds the first one that matches all the required variables, then substitutes the variable values to form the URI

  - the URI listener that does normalized pushState/replaceState

  - browser navigation normalizer

      - hashchange/popstate listener that

          - determines which history index the change corresponds to, or if it's a new one

          - fires a "navigation" event containing the index associated with the change

      - takes normalized pushState/replaceState calls and translates these to either hash changes or window.pushState/window.replaceState

      - translates hash URLs to push state if supported

      - if the current URL is push state and the browser doesn't support it, the next call to pushState will replace the URL (which will cause a page reload)

        this doesn't happen immediately because it would introduce latency for single page viewing

    hashes are supported with a state prefix, e.g.

        foo.com/#0:/bar
        foo.com/#1:/baz

    The implementation must ensure these indices are the same as the history index. (1) the entry page could have been a hash URL with a non-0 prefix and (2) the user could change the URL. In both cases it can change the fragment using `window.location.replace('#...')`

    manually changing the hash erases future history and *may* cause a new state, so it has to be treated as a push

  - listener for this normalized "navigation" event that

    if given an index, 

      - in a Cascade Block:

          1. sets the navigate flag
          2. calls `navigate(index)`

      - after the block:

          1. unsets the navigate flag

    if not, 

      - in a Cascade Block:

          1. sets the route inducing and navigate flags
          2. calls navigate()
          3. calls the client-side URI parser

      - after the block:

          1. unsets the flags

  - client-side URI parser / Router

    takes a proper URI (possibly with a fragment, but the fragment should be a "client fragment" not a fragment to support push state)

    finds the matching route and calls match (which sets its keys) then calls the client-side route function

    equivalent to the express `Router`, but its whole function is called in a Cascade.Block

    set of parameter callbacks set various route variables

    the client-side function sets the additional variables for the matching route. if on the server, this function 

  - client-side route function

    receives a Route instance, which has keys and associated values from the parsed route

    in a Cascade.Block...

    takes these keys & assigns associated route variables. By default, the key to variable association is `user_username` becomes `['route','user','username']`. This can be overwritten per URI variable

    then assigns route variables specific to this route function


Routes can also contain fragments identifying variables that only affect client-side presentation (rather than content or server-side presentation). Scroll position, focus, and text selection are examples. The server-side can also handle these fragments (with a bit of a hack):

    ./route_regex.coffee '/:user_foo_bar#?(#/:baz/:bo,:ho?)?' '/mike#/one/two,three'

The server doesn't have any route variable listeners. If anything changes the route variables, it doesn't matter.

Routes thus consist of these URIs, a function that's called when the var is pending (e.g., "induce route", which sets the route inducing flag and calls navigate()) and an optional set of associated variable values that are set when this route matches and must be set for this route to match. Can also have an optional association from URI variables to an array identifying a path for the variable


#### using express routing
express in principle could be used for the client-side routing

  - can have hooks to parameter names that set outlets
  - can attach a function to the routes that set other outlets

obstacles:

  - callbacks pass req, res

  - the router uses req properties

    e.g., `req.method` for HTTP method

        method
        url
        originalUrl

    but `Router.prototype.match` constructs its own `req` from `method` and `url`

  - won't be able to reuse the connect core

    the logic for the middleware stack has a default error handler that modifies the response with Buffer objects, `setHeader`, etc.

    this would have to be extracted and replaced on the client side with suitable modifiers

    the "response" object on the client could be an object in the Ace instance that sets the outlets

  - some code uses ES5 (e.g., forEach) so won't work in the browser

    this could be resolved with polyfills -- forEach is trivial to add

  - some dependence on Node functions

    url parser in connect

  - the router itself is private API

  - there may be code bloat given that the client won't use much of what's included in the router

    e.g., view rendering

  - param callbacks are invoked before the function callback


Options:

  - fork express and make the necessary changes

      - modularize the routing part and use only that on the client & server

      - could hook into all the route variables

        these hooks are just functions in a hash that's searched by the parameter name

  - rewrite the routing code

    you still have to parse on the client and may want to use express middleware

#### replace state throttling
variables that are updated frequently may be linked to replace state events -- e.g., the contents of a search box

There's a HistoryOutlet called 'URI' that has this function as an outflow. When the function is called, it checks if the "route event" flag is set. If so, it stops its debounce timer, `replaceState` (abstracted) with the previous value then calls `pushState`, otherwise it sets the debounce.

`replaceState` takes the URI proper and transforms it to a hash change or a `window.replaceState` call.

On the server the abstracted `pushState` stops the cascade and responds with a redirect. (this should never happen -- it would mean a given route leads to a set of variable values that immediately causes a push state)

#### QA

unanswered questions:

  - how do cookies and session variables work

  - what does the client do if the set of variables doesn't correspond to a particular route

  - the route variables may have to be re-created if no-reuse controllers/views that hook into them are created. how does this work with both directions (URI change -> variable update and variable update -> URI change)?

  - how does the URI listener know when it's push state vs replace state?

  - how do you ensure when a navigation event happens from the browser that the URI listener doesn't

    the thing forming the URI can all be within the URI function. it can be an OutletMethod with an outflow

  - suppose the URI listener has pending replace states and the user navigates. this means there's a popstate event. that popstate has to tell the this URI listener to cancel the replacements

answered questions:

  - how do variable changes lead to a uniquely identified URI?

    each route has a set of required variables and a set of optional variables. the first route that matches given the current set of variable values is the route. That is, it need not be unique -- the first one matching is used (just like express & rails routing)

### route objects
  - each knows its parameters & whether optional or required
  - can match a URL and assign its parameters

    the *router* object then takes these and calls param hooks

  - can match a set of variables and return a URL

    given a hash of params

## explicit navigate() calls

the views & controllers can call navigate() in a cascade block

the URIListener can subscribe to the beforeNavigate event. When this event is received, it looks at its pending replace state and does it immediately, then calls push state with the currently known URI. When the URIBuilder updates the URI, it's always a replace state call.

### route specification
single file that exports 2 functions like this:

    module.exports = {}

    module.exports.routes = (match) ->
      match '/post/abc', var: 'value'
      match '/:articleUsername/:articleSlug'

    module.exports.vars = (outlets, Variable, ace) ->

      article = new Variable ['ace','articles','article'], (done) ->
        ace.models.articles.findOne {username: outlets.articleUsername.get(), slug: outlets.articleSlug.get()}, (err, doc) ->
          done(doc)

      outlets.articleUsername.set -> article.get().username
      outlets.articleSlug.set -> article.get().slug

match is a function that takes

    uri [, querystring name] [, other variable values]

Variable is a class whose constructor takes

    new Variable(pathArray, function)

this creates an outlet that synchronizes with the history outlets whose function can depend on the (uri) outlets


### RouteHistory

  - maintains route *flags*

    these are not preserved the same way as route variables and other outlets: they're a single set of outlets unaffected by navigation

    and when they're changed, they calculate their 

  - when the route variables are set 

  - before navigating, unplugs the Cascade root, fires the beforeNavigate event, then plugs it back in

    then emits afterNavigate. used by controllers that are `reuse: false`. they register a unique callback for the event when created that calls noInherit in the to. (1) the callback is unique so when re-created later, it's not re-registered and (2) the callbacks are invoked in order. perhaps the uniqueness can be ensured by using prefix unique -- if something has 

### URIBuilder

constructor arguments:

  - route array
  - mapper from route variable paths to URI variable names
  - HistoryOutlets instance

    it has to subscribe to outlet creation events (`newOutlet` event) and add them


uses a variable translator that takes a route variable path (an array like `['route','user','username']`) and returns a string giving the URI variable like `user_username`

it maintains a hash from these URI names to values.

when a new route variable is added, it hooks an outflow to it that assigns to this hash (so it is itself an outflow of the route variables and assigns another outflow functions to the route variable outlets that assigns to this hash)

NOTE: the outflow of the route variable is a function that assigns to this. This way the URIBuilder never has references directly to the route variables (so they can be freed)

all these route variables are inflows to the URIBuilder outlet. Its outlet function is called whenever these change and:

  - iterates through routes array calling match(hash)
  - the first route that returns a string becomes the value of the URIBuilder outlet

Uses URI variables to construct URIs. These variables can be

  - strings

    presented in the URI as their string value

  - hashes

    presented in the URI the same way query strings appear

  - arrays

### URIPusher

outflow of the URIBuilder that checks the navigate/route-inducing flags to call normalized pushState and replaceState

constructor args:

  - URIBuilder outlet
  - route flags outlet
  - browser push/replace state normalizer

    global.

another Outlet instance. it's set to the URIBuilder output

stores the queue of replace events

### route flags

This isn't a separate object. It's a single outlet in the 'route' path in HistoryOutlets

TRAP: this means setting noInherit on the entire route path is disallowed



### Routes

array of route objects, variables, etc.

when route variables are created, the route variable spec/tree is searched for a matching path and the pending function is hooked to it. this should set the appropriate route flag


### BrowserHistory

  - browser navigation events don't necessarily correspond to RouteHistory navigation events (there could be unnecessary navigation events because navigate happens whenever route-inducing variables are pending)


## URIs, client vs server routing, undo/redo
URIs identify *both* the resource and the presentation

e.g., <foo.com/bar.json> vs <foo.com/bar.xml> the resource is <foo.com/bar> and the presentation is json or xml

Furthermore, URIs are split into 2 parts: one part that's sent to the server and another that only the client sees.

The server takes URIs and maps them to variables. The client takes variables and maps them to URIs, so the direction of the routing is inverted. As a result, client and server are calling completely different routines, even if they're both backed by the same descriptive data (a map correlating routes to variables).

The URI is just a token that you send to the server in order to restore what you're seeing in the client.

It's also used for caching.

Client-generated links don't have hrefs. First, it complicates the routing because now the content generation has to know how to generate the URIs instead of focusing on variable changes and second from a user perspective what sense does it make to have something say "this is the (opaque) identifier for the document you *will* see if you click this." The URI for a link can convey useful information (which has to be conveyed in other ways):

  - is the link to the same site or remote?
  - have I seen the content shown by the link before?
  - what's the name of the article that this link will show?

The URI itself is (should be, in principle) meaningless to a user: it's an opaque token used to re-fetch or share a resource view.

History navigation is identical to the undo/redo problem. This is just MVC with undo/redo where the server sends you a snapshot.


## instantiation

calling

    root = new Controller['root']({cid: "ace"});

instantiates the controller then creates its root view with the parameters it's specified, some of which may depend on the route

All the parameters that are passed to the constructor set outlets

controllers and views have a set of default outlets.

TIP: may want to rename the `outlets` parameter `extraOutlets` so it's clear it's not a comprehensive list of all the outlets in the view/controller



## binding and unbinding models

# handling large markdown documents
they're sent from the server as it appears when passed through the lexer. this way, updates can be done incrementally: just by doing array operations

this means the lexer has to be lossless and the client has to store the markdown source, the lexer result, and the DOM representation

updating: the array itself is the data for a controller whose view is a markdown presenter. using the same array operations used in the table view, the document is updated.

editing: the HTML view is "contenteditable" but the moment you press a key or actually edit anything, the text becomes a `pre` with the markdown source with your edit applied, which you can continue to edit. as you edit this (with a throttle) the updates propagate to the lexer and the DOM. the lexer updates modify the array, which modifies the document model from the server


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

## memory

  - controllers/views have to detach any connections to models or queries

# local queries

queries can be done locally if one of these is true:

  - query is on the full collection

    then a query document is formed 

  - query is a subset of an existing query


