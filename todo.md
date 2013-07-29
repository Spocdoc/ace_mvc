 - send a delete event when the session is logged out

    this will tell other windows to log out and will remove it from the database

 - client-side confirm before closing a window with pending socket operations

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

  - reduce number of clone calls in diff and apply. may also want to streamline the object representation

  - optimize query so it doesn't re-create the OJSON format every time the spec changes
