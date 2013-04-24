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


