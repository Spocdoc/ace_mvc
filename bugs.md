# Cascade

  - raw functions that are added as outflows of (deep) multiple cascades are invoked multiple times

    fixing would require changing the implementation to store pending states in a closure, rather than on the objects themselves

    the same could be done with inflows and outflows so the function wouldn't have properties added to it

    another alternative is to just make such functions autoruns

# HistoryOutlet

  - if you call `noInherit` after `ensurePath`, which creates an inherited object, then call `noInherit` on that object, it does nothing because the object is own property (despite inheriting)

        // initially, all of foo is inherited
        noInherit ['foo','bar'] // undefines foo.bar locally
        noInherit ['foo'] // will do nothing


# Navigator

  - when navigating away from the entire site then back to some point in the middle of the site's navigation history, all the data structures have to be restored based on the URL alone. The current implementation resets the index to 0 at the entry point. When you navigate around, the previous induces are overwritten with the new ones, so they're out of sync with the actual order in the browser. This means when `navigate()` is done to a new URL and the array is sliced, data that's still accessible gets cleared.

    The upshot is unnecessary reloading of content that's been erroneously erased. 

    The solution is to use the index as it appears in the push state or hash, rather than overriding it. This means the inheritance in HistoryOutlets has to be more flexible: you may start at index 2 then jump to index 0, so now index 0 inherits from 2.

  - when using hash, there's a flash of the index page followed by loading the target page

  - should "debounce" the calls to replace and ensure that if a push call happens, any pending replace is invoked immediately, the timer reset and then the push called

