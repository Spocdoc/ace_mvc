# stylus

 - write a function for max-height, etc. that uses IE expressions to support IE<8

     example: 

        max-height: 5em;
        _height:unquote('expression(this.scrollHeight > 5 * parseInt(this.currentStyle.fontSize, 10) ?  "5em" : "auto");')


 - similarly, can write something to allow use of color transparent for borders

    add this to the main css:

        // IE transparent color hack
        @css {
          *html {
            filter: chroma(color=#bada55);
          }
        }

    then use this:

        border 1px solid transparent
        *border-color #bada55

  - sourcemaps for CSS

    see [Working with CSS Preprocessors - Chrome DevTools  Google Developers](https://developers.google.com/chrome-developer-tools/docs/css-preprocessors)

    discussion specifiably for stylus here: [Working with CSS Preprocessors - Chrome DevTools  Google Developers](https://developers.google.com/chrome-developer-tools/docs/css-preprocessors)


# MVC

 - currently MVC components can't have more than 1 depth of mixins. if one config mixes in another, the other can't mix in another config or else there's a silent unpredictable config error (the second may not have been fully specified before 

 - why does the model inherit from Base? Is this just for the globals? most of what's in base is not useful to models. maybe there's a lower overhead way of getting the globals into the model

# rebundling bug

most likely has to do with closure. I noticed some variables that had been defined previously wnet missing whenever they were changed


# Socket bugs

 - if the client is paused in debugger mode for a while, the socket will get into an infinite loop once the debugger is resumed

    this is a client-side issue -- if the client is restarted, it's fixed; if the server's restarted, it isn't

    client output:

        1083474 ms ace:cookies               toJSON on cookies [session=%5B%2256ad356a67aec4afcdcf5a95%22%2C%227fed452495bde6ebf4eb89b8ffe1e974ce4c5dc6%22%5D] debug%20[-ie%3C=8%20-ios%20debug].js:42
        1083474 ms ace:cookies               parsingValue on %5B%2256ad356a67aec4afcdcf5a95%22%2C%227fed452495bde6ebf4eb89b8ffe1e974ce4c5dc6%22%5D debug%20[-ie%3C=8%20-ios%20debug].js:42
        1084119 ms ace:cookies               toJSON on cookies [session=%5B%2256ad356a67aec4afcdcf5a95%22%2C%227fed452495bde6ebf4eb89b8ffe1e974ce4c5dc6%22%5D] debug%20[-ie%3C=8%20-ios%20debug].js:42
        1084120 ms ace:cookies               parsingValue on %5B%2256ad356a67aec4afcdcf5a95%22%2C%227fed452495bde6ebf4eb89b8ffe1e974ce4c5dc6%22%5D debug%20[-ie%3C=8%20-ios%20debug].js:42
        1084765 ms ace:cookies               toJSON on cookies [session=%5B%2256ad356a67aec4afcdcf5a95%22%2C%227fed452495bde6ebf4eb89b8ffe1e974ce4c5dc6%22%5D] debug%20[-ie%3C=8%20-ios%20debug].js:42
        1084766 ms ace:cookies               parsingValue on %5B%2256ad356a67aec4afcdcf5a95%22%2C%227fed452495bde6ebf4eb89b8ffe1e974ce4c5dc6%22%5D debug%20[-ie%3C=8%20-ios%20debug].js:42
        1085408 ms ace:cookies               toJSON on cookies [session=%5B%2256ad356a67aec4afcdcf5a95%22%2C%227fed452495bde6ebf4eb89b8ffe1e974ce4c5dc6%22%5D] debug%20[-ie%3C=8%20-ios%20debug].js:42
        1085408 ms ace:cookies               parsingValue on %5B%2256ad356a67aec4afcdcf5a95%22%2C%227fed452495bde6ebf4eb89b8ffe1e974ce4c5dc6%22%5D debug%20[-ie%3C=8%20-ios%20debug].js:42

    server output:

        debug - discarding transport
        debug - discarding transport
        debug - xhr-polling received data packet 5:216+::{"name":"cookies","args":[{"session":["56ad356a67aec4afcdcf5a95","7fed452495bde6ebf4eb89b8ffe1e974ce4c5dc6"]}]}
        debug - client authorized
        info  - handshake authorized H4Ghl39lWboaxS87Co50
        debug - setting request GET /socket.io/1/xhr-polling/H4Ghl39lWboaxS87Co50?t=1386632966465
        debug - setting poll timeout
        debug - client authorized for
        debug - clearing poll timeout
        debug - xhr-polling writing 1::
        debug - set close timeout for client H4Ghl39lWboaxS87Co50
        debug - xhr-polling received data packet 0::
        debug - got disconnection packet
        info  - transport end by forced client disconnection
        info  - transport end (booted)
        debug - cleared close timeout for client H4Ghl39lWboaxS87Co50
        debug - discarding transport
        debug - setting request GET /socket.io/1/xhr-polling/H4Ghl39lWboaxS87Co50?t=1386632966479
        debug - setting poll timeout
        debug - clearing poll timeout
        debug - xhr-polling writing 7:::1+0
        debug - set close timeout for client H4Ghl39lWboaxS87Co50
        warn  - client not handshaken client should reconnect
        info  - transport end (error)
        debug - cleared close timeout for client H4Ghl39lWboaxS87Co50
        debug - discarding transport
        debug - discarding transport
   debug - xhr-polling received data packet 5:217+::{"name":"cookies","args":[{"session":["56ad356a67aec4afcdcf5a95","7fed452495bde6ebf4eb89b8ffe1e974ce4c5dc6"]}]}



# Optimization

 - building templates is slow

    in part because of all the attr calls to jQuery setting the ids of all the elements individually

    there's a chance it would be faster to use an array of string fragments and join them with the prefix then re-parse the HTML

 - building the outlet defaults at every instantiation of the MVC components also takes time

 - the import step takes a while because it has to create all the documents on the client

    this takes about half the time of the import and can lead the client to blow up if it runs out of memory on a huge import. it would be better to send a create request to the server without creating locally

 - the getDisplayTags function is slow

    in part this is because it has to split the tags every time and iterate the parts, then calls delete repeatedly -- it's a slow algorithm

 - remove unnecessary divs by observing that if there's only 1 element in the template, no root wrapper is needed (just add the necessary classes to the top element and link `@$root` to it)

# Bundler

 - the bundles aren't portable

    they export files by inode, then ace looks up the file's inodes a second time using the local files

    instead, the inodes should be associated with the files in the manifest itself and those should be used by ace (rather than looking up the inodes a second time from the disk)


# Usability

 - the syntax for selectors in the ace link could be improved

    1. instead of

            $choices: linkup: ['a', ($target) -> ['select',$target[0].className]]

        it could be 

            $choices: linkup: a: ($target) -> ['select',$target[0].className]

    2. the `this` argument to the function should be the view instance (currently it's nothing)

# Support without JavaScript

 - `contenteditable` elements aren't editable in text-based browsers and since they're not form elements, their content won't be transmitted in graphical browsers without the client-side JavaScript bundle running

    a workaround is to use a special tag in the templates that renders as an input or textarea on the server only and as a div when rendered in the client

    then add to the boot script on the client side something that replaces with divs all the inputs and textareas that have a certain property (e.g., `data-replace` -- remember, jquery is available at that point)

    this would allow form submission without JavaScript (e.g. to do searches or edit the tag list and maps, which use `contenteditable` divs for tag completion) and editing in text-based browses


# Links

 - generating 1000s of links can be slow (20-40 milliseconds to generate them for 2500 tags)

    this is because of the query stringify

    in principle, this could be addressed by creating a function that can be reused, so the whole url doesn't have to be regenerated

    there are a few caveats:

    1) the URL can't use the "uri token' (but that only applies to server-generated links?)

    2) the string part still has to be escaped

# dev

 - the program can't reset itself if there's a compilation error in a file

    if there's an error, it should retain the previous list of watched files and revert to that

 - if the inlets aren't explicitly given, you can't specify them in the constructor of the view

    so this shorthand

         module.exports =
           $top: 'view'
           $bottom: 'view'

    isn't fully equivalent to 

         module.exports =
           inlets: [
             'top'
             'bottom'
           ]

           $top: 'view'
           $bottom: 'view'





