ace = require \brace
# modifies the ace editor config, 
# usage: ..set-theme \ace/theme/monokai
# usage: ..set-mode \ace/mode/livescript
require \brace/theme/monokai
require \brace/mode/livescript
require \brace/ext/searchbox

# modifies the ace editor config
# usage: ..set-options {enable-basic-autocompletion: true}
# allows adding custom auto completers
ace-language-tools = require \brace/ext/language_tools 

# nvd3 requires d3 to be in global space
window.d3 = require \d3-browserify
require \nvd3 

# the first require is used by browserify to import the prelude-ls module
# the second require is defined in the prelude-ls module and exports the object
require \prelude-ls
{concat-map, dasherize, filter, find, find-index, fold, keys, map, obj-to-pairs, Obj, id, pairs-to-obj, sort-by, unique-by, each, all, any, is-type, Str} = require \prelude-ls

# normal dependencies
base62 = require \base62
client-storage = require \./client-storage.ls
{draw-commit-tree} = require \./commit-tree.ls
{conflict-dialog} = require \./conflict-dialog.ls
$ = require \jquery-browserify
{key} = require \keymaster
{get-presentation-context} = require \./presentation-context.ls
{search-queries-by-name, queries-in-same-tree} = require \./queries.ls
{query-search} = require \./query-search.ls
React = require \react
{get-transformation-context} = require \./transformation-context.ls
_ = require \underscore
{compile-and-execute-livescript} = require \./utils.ls

# module-global variables  
chart = null
presentation-editor = null
query-editor = null
transformation-editor = null
parameters-editor = null

# creates, configures & returns a new instance of ace-editor
create-livescript-editor = (element-id)->
    editor = ace.edit element-id
        ..set-options {enable-basic-autocompletion: true}
        ..set-theme \ace/theme/monokai
        ..set-show-print-margin false
        ..get-session!.set-mode \ace/mode/livescript
        ..commands.on \afterExec ({editor, command, args}) ->
            range = editor.getSelectionRange!.clone!
            range.setStart range.start.row, 0
            line = editor.session.getTextRange range
            if command.name == "insertstring" and (/^\$[a-zA-Z]*$/.test args or /.*(\.|\s+[a-zA-Z\$\"\'\(\[\{])$/.test line)
                editor.execCommand \startAutocomplete
        ..on \click, ({dom-event:{meta-key}})-> 
            return if !meta-key
            {row, column} = editor.get-cursor-position!
            session = editor.get-session!            
            current-token = session.get-token-at row, column
            previous-token = (session.get-tokens row)[current-token.index - 2]
            window.open "/branch/#{current-token.value.substr 1}" if previous-token.value == \run-latest-query
                    

# makes a POST request to the server and returns the result of the mongo query
# Note: the request is made only if there is a change in the query
execute-query = do ->

    previous = {}

    (query, parameters, server-name, database, collection, multi-query, cache, callback)->
    
        # compose request object
        request = {            
            server-name
            database
            collection
            query
            parameters
            multi-query
        }

        # return cached response (if any)
        return callback previous.err, previous.result if cache and request `is-equal-to-object` previous.request

        #TODO: use same url for both multi-query and query
        query-result-promise = $.post \/execute, JSON.stringify {cache} <<< request
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
        cache = should-cache!

        (err, result) <- execute-query query, parameters, server-name, database, collection, multi-query, cache

        # hide the preloader
        busy := false
        $ \.preloader .hide!

        # clear existing result
        $ \.output .empty!

        # dispatch a destroy event for presentation context to clear the resize event listeners
        output = $ \.output .get 0
        output.dispatch-event new Event \destroy

        # update the cache indicator
        $ \#cache .parent! .toggle-class "highlight green", cache

        display-error = (err)->
            pre = $ "<pre/>"
            pre.html err.to-string!
            $ \.output .empty! .append pre
            
        # display the new result    
        return display-error "ERROR IN THE QUERY: #{err}" if !!err

        # parameters is livescript code (string)
        if !!parameters and parameters.trim!.length > 0
            [err, parameters-object] = compile-and-execute-livescript parameters, {}
            console.log err if !!err

        parameters-object ?= {}

        [err, result] = compile-and-execute-livescript transformation, {result: JSON.parse result} <<< get-transformation-context! <<< parameters-object <<< (require \prelude-ls)
        return display-error "ERROR IN THE TRANSFORMATION CODE: #{err}" if !!err

        [err, result] = compile-and-execute-livescript presentation, {result, d3, $, view: ($ \.output .get 0)} <<< get-transformation-context! <<< parameters-object <<< (require \prelude-ls) <<< get-presentation-context!
        return display-error "ERROR IN THE PRESENTATION CODE: #{err}" if !!err

# if the local state has diverged from remote state, creates a new tree
# returns the url of the forked query 
fork = ({query-id, tree-id}:document-state, remote-document-states) ->
    changed = has-document-changed document-state, remote-document-states
    encoded-time = base62.encode Date.now!    
    forked-document-state = get-document-state {
        query-id: encoded-time
        parent-id: query-id
        branch-id: \local-fork
        tree-id
    }
    forked-document-state.query-name = "Copy of #{forked-document-state.query-name}"
    client-storage.save-document-state forked-document-state.query-id, forked-document-state
    reset-document-sate query-id, remote-document-states
    "/branch/local/#{forked-document-state.query-id}"

# gets the document state from the dom elements
get-document-state = ({query-id, tree-id, branch-id, parent-id}:identifiers?)->
    {} <<< (if !!identifiers then {query-id, tree-id, branch-id, parent-id} else {}) <<< {
        query-name: $ \#query-name .val!
        server-name: $ \#server-name .val!
        database: $ \#database .val!,
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

# get identifiers from local storage, remote state, null otherwise
get-identifiers = (url, remote-document-states)->

        # extract from url & local storage using regex (branch/local/local-query-id)
        [, , query-id]? = url.match new RegExp "http\\:\\/\\/(.*)?\\/branch\\/local/([a-zA-Z0-9]+)/?"
        return {branch-id: \local, query-id} if !!query-id

        # extract from url & local storage using regex (branch/local/local-query-id)
        [, , query-id]? = url.match new RegExp "http\\:\\/\\/(.*)?\\/branch\\/local-fork/([a-zA-Z0-9]+)/?"
        return {branch-id: \local-fork, query-id} if !!query-id

        # extract from url & local storage using regex (branch/branch-id/query-id)
        [, , branch-id, query-id]? = url.match new RegExp "http\\:\\/\\/(.*)?\\/branch\\/([a-zA-Z0-9]+)/([a-zA-Z0-9]+)/?"
        if !!query-id
            {query-id, branch-id, parent-id, tree-id}? = client-storage.get-document-state query-id
            return {query-id, branch-id, parent-id, tree-id} if !!query-id

        # extract from the server response
        {query-id, branch-id, parent-id, tree-id}? = remote-document-states.0
        return {query-id, branch-id, parent-id, tree-id} if !!query-id

        null

# gets the query parameters from the url
get-query-parameters = ->
    [url, domain, query-id, query-parameters]? = window.location.href.match page-url-regex
    try-get query-parameters, ""

# returns noop if the document hasn't changed since the last save
get-save-function = ({query-id, branch-id, tree-id, parent-id}:document-state, remote-document-states)->

    # if there are no changes to the document return noop as the save function
    return [false, (callback)-> callback null] if !has-document-changed document-state, remote-document-states

    # if the document has changed since the last save then 
    # return a function that will POST the new document to the server
    [
        true
        (callback)->

            # resolve the conflict creating a new commit or forking a new branch
            resolve-conflict = (queries-in-between, get-parent-query-id)->

                conflict-dialog-container = $ ".conflict-dialog-container" .get 0
                encoded-time = base62.encode Date.now!

                React.render do 
                    conflict-dialog do
                        queries: queries-in-between
                        on-resolved: (resolution)-> 
                            match resolution
                                # option #1: create a new commit & place it at the head
                                | \new-commit =>
                                    save-and-push-state {} <<< document-state <<< {
                                        query-id: encoded-time                    
                                        parent-id: get-parent-query-id resolution
                                    }

                                # option #2: fork a new branch
                                | \fork 
                                    save-and-push-state {} <<< document-state <<< {
                                        query-id: encoded-time
                                        branch-id: encoded-time
                                        parent-id: get-parent-query-id resolution
                                    }

                                # option #3: delete local storage and reset to history.state
                                | \reset =>
                                    return if !confirm "Are you sure you want to reset your changes?"
                                    client-storage.delete-document-state query-id
                                    update-dom-with-document-state history.state

                            
                    conflict-dialog-container

            # save the state, reset local storage and update history
            save-and-push-state = (document-state)->

                err <- save-to-server document-state

                if !!err                    

                    error-json = try-parse-json err

                    if !!error-json?.queries-in-between
                        resolve-conflict error-json.queries-in-between, (resolution)-> if resolution == \new-commit then error-json.queries-in-between.0 else query-id
                        return callback null

                    return callback err

                history.push-state document-state, document-state.name, "/branch/#{document-state.branch-id}/#{document-state.query-id}"
                remote-document-states.unshift document-state
                client-storage.delete-document-state query-id
                callback null
                            

            # non fast-forward case
            if !!remote-document-states.0?.query-id and query-id != remote-document-states.0?.query-id

                # make sure that the head is saved
                client-head-state = client-storage.get-document-state remote-document-states.0.query-id
                if !!client-head-state and has-document-changed client-head-state, remote-document-states
                    return callback "Please save the head query"

                # display conflict resolution dialog
                resolution <- resolve-conflict [0 til remote-document-states |> find-index (.query-id == query-id)] 
                if resolution == \new-commit then remote-document-states.0.query-id else query-id

            # fast-forward
            else

                encoded-time = base62.encode Date.now!

                # the parent id of forked queries is computed at the time of there creation
                new-parent-id = match branch-id
                    | \local => null
                    | \local-fork => parent-id
                    | _ => query-id

                save-and-push-state {} <<< document-state <<< {
                    query-id: encoded-time
                    parent-id: new-parent-id
                    branch-id: if (branch-id.index-of \local) == 0 then encoded-time else branch-id
                    tree-id: tree-id || encoded-time                    
                }
                

    ]

# compares document-state with remote document state
has-document-changed = ({query-id}:document-state, remote-document-states)->

    remote-document-state = (remote-document-states |> find (.query-id == query-id)) or remote-document-states.0

    keys = <[ui queryId branchId parentId localQueryId]>
    !(omit document-state, keys) `is-equal-to-object` omit remote-document-state, keys

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

# returns a new object by omiting keys from the source object
omit = (obj, keys)->
    obj 
        |> obj-to-pairs
        |> filter ([key, ...]) -> (keys.index-of key) == -1
        |> pairs-to-obj

# utility function, converts a string to boolean
parse-bool = -> it == \true

#
reset-document-sate = (query-id, remote-document-states)->
    client-storage.delete-document-state query-id
    document-state = remote-document-states |> find (.query-id == query-id)
    update-dom-with-document-state document-state
    update-remote-state-button document-state, remote-document-states

# update the ace-editors after there corresponding div elements have been resized
resize-editors = -> [query-editor, transformation-editor, presentation-editor] |> map (.resize!)

# update the size of elements based on editor & window width & height
resize-ui = ->
    $ \.output .width window.inner-width - ($ \.editors .width!) - ($ \.resize-handle.vertical .width!)
    $ \.output .height window.inner-height - ($ \.menu .height!)

    # trigger resize event on the output element for the presentation context
    output = $ \.output .get 0
    output.dispatch-event new Event \resize

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

# makes a POST request to the server to save the current document-object
save-to-server = (document-state, callback)->
    save-request-promise = $.post \/save, (JSON.stringify document-state, null, 4)
        ..done (response)-> callback null
        ..fail ({response-text}?)-> callback (response-text or "SERVER ERROR")

# returns true if the cache checkbox in the UI is enabled
should-cache = -> ($ '#cache:checked' .length) > 0

# a convenience function
try-get = (value, default-value)-> if !!value then value else default-value

# tries to parse json string, returns null on failure
try-parse-json = (json-string)->

    json = null

    try
        json = JSON.parse json-string
    catch parse-exception
        return null

    json

# update the editors, document.title etc using the document-state (persisted to local-storage and server)
update-dom-with-document-state = ({query-name, server-name, database, collection, query, parameters, transformation, presentation, multi-query, ui}, update-ui = true)->
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
    if update-ui
        if !!ui
            if !!ui.editors
                ui.editors 
                    |> filter ({id}) -> id != \parameters-editor
                    |> each ({id, height}) -> $ '#' + id .css \height, height
            if !!ui.left-editors-width
                $ \.editors .css \width, ui.left-editors-width
        resize-ui!
        resize-editors!

# the state button is only visible when there is copy of the query on the server
# the highlight on the state button indicates the client version differs the server version
update-remote-state-button = (document-state, remote-document-states)->
    $ \#remote-state .toggle !!remote-document-states.0.query-id
    $ \#remote-state .toggle-class "highlight orange" (has-document-changed document-state, remote-document-states)

# on dom ready
$ ->

    # setup the initial size
    $ \.editors .width window.inner-width * 0.4
    empty-space = (window.inner-height - $ \.menu .outer-height!) - 3 * ($ \.editor-name .outer-height! + $ \.resize-handle.horizontal .outer-height!)
    $ \.editor .height empty-space / 3

    resize-ui!

    # width adjustment handle
    $ \.resize-handle.vertical .unbind \mousedown .bind \mousedown, (e1)->
        initial-width = $ \.editors .width!

        $ window .unbind \mousemove .bind \mousemove, (e2)->            
            $ \.editors .width (initial-width + (e2.page-x - e1.page-x))
            resize-editors!
            resize-ui!

        $ window .unbind \mouseup .bind \mouseup, -> $ window .unbind \mousemove .unbind \mouseup

    # height adjustment handle
    $ \.resize-handle.horizontal .unbind \mousedown .bind \mousedown, (e1)->
        $editor = $ e1.original-event.current-target .prev-all! .filter \div:first
        initial-height = $editor .height!

        $ window .unbind \mousemove .bind \mousemove, (e2)-> 
            $editor.height (initial-height + (e2.page-y - e1.page-y))
            resize-editors!
            resize-ui!

        $ window .unbind \mouseup .bind \mouseup, -> $ window .unbind \mousemove .unbind \mouseup

    # resize the chart on window resize
    window.onresize = resize-ui

    # create the editors
    query-editor := create-livescript-editor \query-editor
    transformation-editor := create-livescript-editor \transformation-editor
    presentation-editor := create-livescript-editor \presentation-editor
    parameters-editor := create-livescript-editor \parameters-editor

    # load document & update DOM, editors
    {query-id}? = get-identifiers window.location.href, window.remote-document-states

    document-state = {}

    if !!query-id
        document-state = (client-storage.get-document-state query-id) or {} <<< window.remote-document-states.0
        
    else 
        document-state = {} <<< window.remote-document-states.0 <<< {branch-id: \local, query-id: base62.encode Date.now!}            

    history.replace-state document-state, document-state.name, "/branch/#{document-state.branch-id}/#{document-state.query-id}"
    update-dom-with-document-state document-state

    # auto-complete mongo keywords, transformation-context keywords & presentation-context keywords
    do ->

        # returns dasherized collection of keywords for auto-completion
        keywords-from-context = (context)->
            context
                |> obj-to-pairs 
                |> map -> dasherize it.0

        # takes a collection of keywords & maps them to {name, value, score, meta}
        convert-to-ace-keywords = (keywords, meta, prefix)->
            keywords
                |> map -> {text: it, meta: meta}
                |> filter -> it.text.index-of(prefix) == 0 
                |> map -> {name: it.text, value: it.text, score: 0, meta: it.meta}


        alphabet = [(String.fromCharCode i) for i in [65 to 65+25] ++ [97 to 97+25] ]

        # auto complete for mongo collection properties
        {server-name, database, collection} = get-document-state!
        query-context-keywords <- $.get "/keywords/queryContext"
        collection-keywords <- $.get "/keywords/#{server-name}/#{database}/#collection"

        query-editor-keywords = do ->
            alphabet ++
            query-context-keywords ++
            collection-keywords ++
            # generated by utilities/mongo-keywords.js
            <[$add $add-to-set $all-elements-true $and $any-element-true $avg $cmp $concat $cond $day-of-month $day-of-week $day-of-year $divide 
            $eq $first $geo-near $group $gt $gte $hour $if-null $last $let $limit $literal $lt $lte $map $match $max $meta $millisecond $min $minute $mod $month 
            $multiply $ne $not $or $out $project $push $redact $second $set-difference $set-equals $set-intersection $set-is-subset $set-union $size $skip $sort 
            $strcasecmp $substr $subtract $sum $to-lower $to-upper $unwind $week $year]>

        transformation-editor-keywords = do ->
            ([get-transformation-context!, (require \prelude-ls)] |> concat-map keywords-from-context) ++ alphabet

        presentation-editor-keywords-d3 = keywords-from-context d3

        presentation-editor-keywords = do ->            
            ([get-presentation-context!, (require \prelude-ls)] |> concat-map keywords-from-context) ++ alphabet

        console.log presentation-editor-keywords

        ace-language-tools.add-completer {
            # :: Editor -> EditSession -> Range -> prefix :: String -> callback
            get-completions: (editor, , , prefix, callback) ->
                r = editor.getSelectionRange!.clone!
                    ..set-start r.start.row, 0
                text = editor.session.get-text-range r

                [keywords, meta] = match editor.container.id
                | \query-editor => [query-editor-keywords, \mongo]
                | \transformation-editor => [transformation-editor-keywords, \transformation]
                | \presentation-editor => [(if /.*d3\.($|[\w-]+)$/i.test text then presentation-editor-keywords-d3 else presentation-editor-keywords), \presentation]
                | _ => [alphabet, editor.container.id]

                callback null, (convert-to-ace-keywords keywords, meta, prefix)
        }

    # update document title with query-name
    $ \#query-name .on \input, -> document.title = $ @ .val!

    # save to local storage as soon as the user idles for more than half a second after any keydown
    on-key-down = ->

        # do not save if we are displaying server side version
        return if ($ \#remote-state .attr \data-state) == \server

        document-state = get-document-state history.state

        if has-document-changed document-state, window.remote-document-states
            client-storage.save-document-state document-state.query-id, document-state

        else
            client-storage.delete-document-state document-state.query-id

        update-remote-state-button document-state, window.remote-document-states

    document .add-event-listener \keydown, (_.debounce on-key-down, 500), true
    on-key-down!

    # save to server 
    save-state = (document-state)->

        # do not save if we are displaying server side version
        return if ($ \#remote-state .attr \data-state) == \server

        [, save-function] = get-save-function document-state, window.remote-document-states

        # update the difference indicator between client & server code
        save-function (err)-> 
            return alert err if !!err
            update-remote-state-button history.state, window.remote-document-states

        # prevent default behaviour of displaying the save-dialog
        false

    key 'command + s', (e)-> save-state get-document-state history.state
    $ \#save .on \click, (e)-> save-state get-document-state history.state

    # execute the query on button click or hot key (command + enter)
    key 'command + enter', -> execute-query-and-display-results get-document-state history.state
    $ \#execute-query .on \click, -> execute-query-and-display-results get-document-state history.state

    # fork
    $ \#fork .on \click, ->
        url = fork (get-document-state history.state), window.remote-document-states
        window.open url, \_blank

    # # info
    $ \#info .on \click, -> $ \.details .toggle!
    $ \#params .on \click, -> $ \.parameters .toggle!

    # # switch between client & server code
    $ \#remote-state .on \click, ->
        
        if ($ @ .attr \data-state) == \client
            $ @ .attr \data-state, \server
            [query-editor, transformation-editor, presentation-editor, parameters-editor] |> map -> it.set-read-only true            
            document-state = get-document-state history.state
            client-storage.save-document-state document-state.query-id, document-state
            update-dom-with-document-state do 
                window.remote-document-states |> find (.query-id == history.state.query-id)
                false
            
        else
            $ @ .attr \data-state, \client
            [query-editor, transformation-editor, presentation-editor, parameters-editor] |> map -> it.set-read-only false            
            update-dom-with-document-state do
                client-storage.get-document-state history.state.query-id
                false

    $ \#commit-tree .on \click, ->
        window.open "/tree/#{history.state.query-id}"

    $ \#multi-query .on \change, -> 
        update-remote-state-button get-document-state history.state, window.remote-document-states

    # # reset local document state to match remote version
    $ \#reset-to-server .on \click, ->
        return if !confirm "Are you sure you want to reset query to match server version?"
        reset-document-sate history.state.query-id, window.remote-document-states

    # # prevent loss of work, does not guarantee the completion of async functions    
    window.onbeforeunload = ->
        dirty-states = window.remote-document-states
            |> filter ({query-id})->
                document-state = client-storage.get-document-state query-id
                !!document-state and has-document-changed document-state, window.remote-document-states
        return "You have NOT saved your query. Stop and save if your want to keep your query." if dirty-states.length > 0 || (typeof window.remote-document-states.0.query-id == \undefined)

    window.onpopstate = (event)->
        local-state = client-storage.get-document-state event.state.query-id
        document-state = if !!local-state then local-state else event.state
        update-dom-with-document-state document-state
        update-remote-state-button document-state, window.remote-document-states

    # query search
    $query-search-container = $ \.query-search-container .get 0

    key 'command + p, command + shift + p', (e)-> 
        React.render (query-search {
            on-query-selected: ({branch-id, query-id})-> 
                window.open "/branch/#{branch-id}/#{query-id}", \_blank
                React.unmount-component-at-node $query-search-container
        }), $query-search-container
        false

    key 'esc', -> React.unmount-component-at-node $query-search-container
    


