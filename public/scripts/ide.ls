ace = require \brace

# modifies the ace editor config, 
# usage: ..set-theme \ace/theme/monokai
# usage: ..set-mode \ace/mode/livescript
require \brace/theme/monokai
require \brace/mode/livescript

# modifies the ace editor config
# usage: ..set-options {enable-basic-autocompletion: true}
# allows adding custom auto completers
ace-language-tools = require \brace/ext/language_tools 

# nvd3 requires d3 to be in global space
window.d3 = require \d3-browserify
require \nvd3 

# the first require is used by browserify to import the LiveScript module
# the second require is defined in the LiveScript module and exports the object
require \LiveScript
{compile} = require \LiveScript

# the first require is used by browserify to import the prelude-ls module
# the second require is defined in the prelude-ls module and exports the object
require \prelude-ls
{dasherize, filter, find, fold, keys, map, obj-to-pairs, Obj, id, pairs-to-obj, sort-by, unique-by, each, all, any, is-type} = require \prelude-ls

# normal dependencies
$ = require \jquery-browserify
{key} = require \keymaster
{get-presentation-context} = require \./presentation-context.ls
{query-search} = require \./query-search.ls
React = require \react
{get-transformation-context} = require \./transformation-context.ls
_ = require \underscore

# module-global variables  
chart = null
presentation-editor = null
query-editor = null
transformation-editor = null
parameters-editor = null
page-url-regex = new RegExp "http\\:\\/\\/(.*)?\\/query\\/(\\d+)(\\#\\?.*)?"

# creates, configures & returns a new instance of ace-editor
create-livescript-editor = (element-id)->
    ace.edit element-id
        ..set-options {enable-basic-autocompletion: true}
        ..set-theme \ace/theme/monokai
        ..set-show-print-margin false
        ..get-session!.set-mode \ace/mode/livescript

# takes a collection of keywords & maps them to {name, value, score, meta}
convert-to-ace-keywords = (keywords, meta, prefix)->
    keywords
        |> map -> {text: it, meta: meta}
        |> filter -> it.text.index-of(prefix) == 0 
        |> map -> {name: it.text, value: it.text, score: 0, meta: it.meta}

# filters out empty lines and lines that begin with comment
# also encloses the query objects in a collection
convert-query-to-valid-livescript = (query)->

    lines = query.split (new RegExp "\\r|\\n")
        |> filter -> 
            line = it.trim!
            !(line.length == 0 || line.0 == \#)

    lines = [0 til lines.length] 
        |> map (i)-> 
            line = lines[i]
            line = (if i > 0 then "},{" else "") + line if line.0 == \$
            line

    "[{#{lines.join '\n'}}]"

# makes a POST request to the server and returns the result of the mongo query
# Note: the request is made only if there is a change in the query
execute-query = do ->

    previous = {}

    (query, parameters, server-name, database, collection, multi-query, cache, callback)->
    
        # TODO: fix
        cache = false

        if not multi-query
            query = convert-query-to-valid-livescript query

        # compose request object
        request = {            
            server-name
            database
            collection
            query
            parameters
            cache
        }

        # return cached response (if any)
        return callback previous.err, previous.result if request `is-equal-to-object` previous.request

        #TODO: use same url for both multi-query and query
        query-result-promise = $.post (if multi-query then \/multi-query else \/execute), JSON.stringify request
            ..done (response)->                 
                previous <<< {request, err: null, result: response}
                callback null, response

            ..fail ({response-text}) -> callback response-text, null

# uses the execute-query function and presents the results after appling the transformation
execute-query-and-display-results = do ->

    busy = false

    ({server-name, database, collection, parameters, query, transformation, presentation, multi-query}:document-state)->
    
        return if busy
        busy := true

        # show preloader
        $ \.preloader .show!        

        # query, transform & plot         
        (err, result) <- execute-query query, parameters, server-name, database, collection, multi-query, true

        busy := false

        $ \.preloader .hide!

        # clear existing result
        $ \pre .html ""
        $ \svg .empty!

        display-error = (err)->
            show-output-tag \pre
            $ \pre .html err

        # display the new result    
        return display-error "query-editor error #{err}" if !!err

        [err, result] = run-livescript get-transformation-context!, (JSON.parse result), transformation
        return display-error "transformer error #{err}" if !!err

        [err, result] = run-livescript (get-presentation-context chart, plot-chart, show-output-tag), result, presentation
        return display-error "presenter error #{err}" if !!err

# gets the documetn state from the dom elements
get-document-state = (query-id)->
    {
        query-id
        query-name: $ \#query-name .val!
        server-name: $ \#server-name .val!
        database: $ \#database .val!
        collection: $ \#collection .val!
        query: query-editor.get-value!
        transformation: transformation-editor.get-value!
        presentation: presentation-editor.get-value!
        parameters: parameters-editor.get-value!
        multi-query: $ \#multi-query .0.checked
        ui: 
            left-editors-width: $ \.editors .width!
            editors:
                $ \.editor .map -> 
                    self = $ this
                    id: (self.attr \id), height: self.height!
                .to-array!
    }

# converts the hash query string to object
get-hash = -> 
    (window.location.hash.replace \#?, "").split \& 
        |> map (.split \=) 
        |> pairs-to-obj

## gets the query id from the url
get-query-id = do ->

    result = null

    (url)->
        return result if !!result

        [url, domain, query-id, query-parameters]? = window.location.href.match page-url-regex
        result := parse-int try-get query-id, new Date!.get-time!

# gets the query parameters from the url
get-query-parameters = ->
    [url, domain, query-id, query-parameters]? = window.location.href.match page-url-regex
    try-get query-parameters, ""

# returns noop if the document hasn't changed since the last save
get-save-function = (document-state)->

    # if there are no changes to the document return noop as the save function
    return [false, (callback)-> callback! if !!callback] if document-state `is-equal-to-object` window.remote-document-state

    # if the document has changed since the last save then 
    # return a function that will POST the new document to the server
    [
        true
        (callback)->        

            # update the local-storage before making the request to recover from unexpected crash
            save-to-local-storage document-state

            (err) <- save-to-server document-state
            return console.log err if !!err

            window.remote-document-state = document-state
            callback! if !!callback

    ]

# two objects are equal if they have the same keys & values
is-equal-to-object = (o1, o2)->
    return o1 == o2 if <[Boolan Number String]> |> any -> is-type it, o1
    return false if (typeof o1 == \undefined || o1 == null) || (typeof o2 == \undefined || o2 == null)
    (keys o1) |> all (key) ->
        if is-type \Object o1[key]
            o1[key] `is-equal-to-object` o2[key]
        else if is-type \Array o1[key]
            return false if o1.length != o2.length
            [1 to o1.length] |> -> all o1[it] `is-equal-to-object` o2[it]
        else
            o1[key] == o2[key]

# returns dasherized collection of keywords for auto-completion
keywords-from-context = (context)->
    context
        |> obj-to-pairs 
        |> map -> dasherize it.0

# tries to load the document state from local-storage on failure returns the remote document state
load-document-state = (query-id)->
    state = if !!(local-storage.get-item query-id) then JSON.parse (local-storage.get-item query-id) else {} <<< window.remote-document-state
    state <<< {query-id}    

# utility function, converts a string to boolean
parse-bool = -> it == \true

# DRY function used by presentation-context
plot-chart = (chart, result)->
    show-output-tag \svg
    d3.select \svg .datum result .call chart

# update the ace-editors after there corresponding div elements have been resized
resize-editors = -> [query-editor, transformation-editor, presentation-editor] |> map (.resize!)

# update the size of elements based on editor & window width & height
resize = ->
    $ \.output .width window.inner-width - ($ \.editors .width!) - ($ \.resize-handle.vertical .width!)
    $ \.output .height window.inner-height - ($ \.menu .height!)
    $ "pre, svg" .width ($ \.output .width!)
    $ "pre, svg" .height ($ \.output .height!)
    $ \.resize-handle.vertical .height Math.max ($ \.output .height!), ($ \.editors .height!)
    $ \.preloader 
        ..css {left: $ \.output .offset!.left, top: $ \.output .offset!.top}
        ..width ($ \.output .width!)
        ..height ($ \.output .height!)    
    $ \.details .css \left, 
        ($ \#info .offset!.left - ($ \.details .outer-width! - $ \#info .outer-width!) / 2)
    $ \.parameters .css \left, 
        ($ \#params .offset!.left - ($ \.parameters .outer-width! - $ \#info .outer-width!) / 2)
    chart.update! if !!chart

# compiles & executes livescript
run-livescript = (context, result, livescript)-> 
    livescript = "window <<< require 'prelude-ls' \nwindow <<< context \n" + livescript       
    try 
        return [null, eval compile livescript, {bare: true}]
    catch error 
        return [error, null]

# makes a POST request to the server to save the current document-object
save-to-server = (document-state, callback)->
    save-request-promise = $.post \/save, (JSON.stringify document-state, null, 4)
        ..done (response)->
            [err, document-state] = JSON.parse response
            return callback err if !!err
            callback null
        ..fail ({response-text})-> callback response-text

# save document with query-id to local storage
# putting the query-id makes it consistent with the db & makes setting up the history easier
save-to-local-storage = (document-state)-> 
    local-storage.set-item document-state.query-id, JSON.stringify document-state

# converts an object to hash query string
set-hash = (obj)->
    window.location.hash = {} <<< get-hash! <<< obj  
        |> obj-to-pairs 
        |> map (.join \=)
        |> (.join \&)
        |> -> "#?#{it}"

# toggle between pre (for json & table) and svg (for charts)
show-output-tag = (tag)->
    $ \.output .children! .each -> 
        $ @ .css \display, if ($ @ .prop \tagName).to-lower-case! == tag then "" else \none

# a convenience function
try-get = (value, default-value)-> if !!value then value else default-value

# update the editors, document.title etc using the document-state (persisted to local-storage and server)
update-dom-with-document-state = ({query-name, server-name, database, collection, query, parameters, transformation, presentation, multi-query, ui})->
    document.title = query-name
    $ \#query-name .val query-name
    $ \#server-name .val server-name
    $ \#database .val database
    $ \#collection .val collection
    $ \#multi-query .0.checked = multi-query
    query-editor.set-value query
    parameters-editor.set-value parameters
    transformation-editor.set-value transformation
    presentation-editor.set-value presentation
    [query-editor, transformation-editor, presentation-editor, parameters-editor] |> map -> it.session.selection.clear-selection!
    if !!ui
        if !!ui.editors
            ui.editors |> each ({id, height}) -> $ '#' + id .css \height, height
        if !!ui.left-editors-width
            $ \.editors .css \width, ui.left-editors-width

# the state button is only visible when there is copy of the query on the server
# the highlight on the state button indicates the client version differs the server version
update-remote-state-button = (document-state)->
    $ \#remote-state .toggle !!window.remote-document-state.query-id
    $ \#remote-state .toggle-class \highlight !(document-state `is-equal-to-object` window.remote-document-state)

# on dom ready
$ ->

    show-output-tag \pre

    # setup the initial size
    $ \.editors .width window.inner-width * 0.4
    empty-space = (window.inner-height - $ \.menu .outer-height!) - 3 * ($ \.editor-name .outer-height! + $ \.resize-handle.horizontal .outer-height!)
    $ \.editor .height empty-space / 3

    resize!

    # width adjustment handle
    $ \.resize-handle.vertical .unbind \mousedown .bind \mousedown, (e1)->
        initial-width = $ \.editors .width!

        $ window .unbind \mousemove .bind \mousemove, (e2)->            
            $ \.editors .width (initial-width + (e2.page-x - e1.page-x))
            resize-editors!
            resize!

        $ window .unbind \mouseup .bind \mouseup, -> $ window .unbind \mousemove .unbind \mouseup

    # height adjustment handle
    $ \.resize-handle.horizontal .unbind \mousedown .bind \mousedown, (e1)->
        $editor = $ e1.original-event.current-target .prev-all! .filter \div:first
        initial-height = $editor .height!

        $ window .unbind \mousemove .bind \mousemove, (e2)-> 
            $editor.height (initial-height + (e2.page-y - e1.page-y))
            resize-editors!
            resize!

        $ window .unbind \mouseup .bind \mouseup, -> $ window .unbind \mousemove .unbind \mouseup

    # resize the chart on window resize
    window.onresize = resize

    # create the editors
    query-editor := create-livescript-editor \query-editor
    transformation-editor := create-livescript-editor \transformation-editor
    presentation-editor := create-livescript-editor \presentation-editor
    parameters-editor := create-livescript-editor \parameters-editor

    # auto-complete mongo keywords, transformation-context keywords & presentation-context keywords
    ace-language-tools
        ..add-completer {
            get-completions: (, , , prefix, callback)->

                # generated by utilities/mongo-keywords.js
                mongo-keywords = <[$add $add-to-set $all-elements-true $and $any-element-true $avg $cmp $concat $cond $day-of-month $day-of-week $day-of-year $divide 
                $eq $first $geo-near $group $gt $gte $hour $if-null $last $let $limit $literal $lt $lte $map $match $max $meta $millisecond $min $minute $mod $month 
                $multiply $ne $not $or $out $project $push $redact $second $set-difference $set-equals $set-intersection $set-is-subset $set-union $size $skip $sort 
                $strcasecmp $substr $subtract $sum $to-lower $to-upper $unwind $week $year]>
                
                callback null, convert-to-ace-keywords mongo-keywords, \mongo, prefix
        }
        ..add-completer { get-completions: (, , , prefix, callback)-> callback null, convert-to-ace-keywords (keywords-from-context get-transformation-context!), \transformation, prefix }
        ..add-completer { get-completions: (, , , prefix, callback)-> callback null, convert-to-ace-keywords (keywords-from-context get-presentation-context!), \presentation, prefix }

    # auto complete for mongo collection properties
    $.get "/keywords/queryContext", (collection-keywords)-> 
        ace-language-tools.add-completer { get-completions: (, , , prefix, callback)-> callback null, convert-to-ace-keywords (JSON.parse collection-keywords), \collection, prefix }
        
    # load document & update DOM, editors
    query-id = get-query-id!
    document-state = load-document-state query-id
    history.replace-state document-state, document-state.name, "/query/#{query-id}#{get-query-parameters!}"
    update-dom-with-document-state document-state

    # update document title with query-name
    $ \#query-name .on \input, -> document.title = $ @ .val!

    # save to local storage as soon as the user idles for more than half a second after any keydown
    on-key-down = ->

        # do not save if we are displaying server side version
        return if ($ \#remote-state .attr \data-state) == \server

        document-state = get-document-state query-id
        save-to-local-storage document-state
        update-remote-state-button document-state

    document .add-event-listener \keydown, (_.debounce on-key-down, 500), true
    on-key-down!

    # save to server 
    on-save = (e, document-state)->

        # do not save if we are displaying server side version
        return if ($ \#remote-state .attr \data-state) == \server

        [,save-function] = get-save-function document-state

        # update the difference indicator between client & server code
        save-function -> update-remote-state-button document-state

        # prevent default behaviour of displaying the save-dialog
        false

    key 'command + s', (e)-> on-save e, get-document-state query-id
    $ \#save .on \click, (e)-> on-save e, get-document-state query-id

    # execute the query on button click or hot key (command + enter)
    key 'command + enter', -> execute-query-and-display-results get-document-state query-id
    $ \#execute-query .on \click, -> execute-query-and-display-results get-document-state query-id

    # fork
    $ \#fork .on \click, ->
        new-query-id = new Date!.get-time!
        forked-document-state = get-document-state new-query-id
        forked-document-state.query-name = "Copy of #{forked-document-state.query-name}"
        local-storage.set-item new-query-id, JSON.stringify forked-document-state
        window.open "/#{new-query-id}", \_blank

    # info
    $ \#info .on \click, -> $ \.details .toggle!
    $ \#params .on \click, -> $ \.parameters .toggle!

    # delete
    $ \#delete .on \click, -> 
        return if !confirm "Are you sure you want to delete this query?"
        <- $.get "/delete/#{query-id}"
        local-storage.remove-item "#{query-id}"
        window.onbeforeunload = $.noop!
        window.location.href = "list?_=#{new Date!.get-time!}"

    # switch between client & server code
    $ \#remote-state .on \click, ->
        
        if ($ @ .attr \data-state) == \client
            $ @ .attr \data-state, \server
            [query-editor, transformation-editor, presentation-editor, parameters-editor] |> map -> it.set-read-only true            
            update-dom-with-document-state window.remote-document-state
            
        else
            $ @ .attr \data-state, \client
            [query-editor, transformation-editor, presentation-editor, parameters-editor] |> map -> it.set-read-only false
            update-dom-with-document-state JSON.parse local-storage.get-item query-id                

    $ \#reset-to-server .on \click, ->
        return if !confirm "Are you sure you want to reset query to match server version?"
        update-dom-with-document-state window.remote-document-state
        update-remote-state-button window.remote-document-state

    # prevent loss of work, does not guarantee the completion of async functions    
    window.onbeforeunload = -> 
        save-to-local-storage get-document-state query-id
        [should-save] = get-save-function get-document-state query-id
        return "You have NOT saved your query. Stop and save if your want to keep your query." if should-save

    # query search
    $query-search-container = $ \.query-search-container .get 0

    key 'command + p, command + shift + p', (e)-> 
        React.render (query-search {
            on-query-selected: ({query-id})-> 
                window.open "/#{query-id}", \_blank
                React.unmount-component-at-node $query-search-container
        }), $query-search-container
        cancel-event e

    key 'esc', -> React.unmount-component-at-node $query-search-container



































