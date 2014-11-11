{dasherize, filter, fold, keys, map, obj-to-pairs, Obj, pairs-to-obj, id} = require \prelude-ls
{compile} = require \LiveScript

# global variables  
chart = null
presentation-editor = null 
query-editor = null
transformation-editor = null
page-url-regex = new RegExp "http\\:\\/\\/(.*)?\\/(\\d+)(\\#\\?.*)?"

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

# makes a POST request the server and returns the result of the mongo query
# Note: the request is made only if there is a change in the query
execute-query = (->

    previous = {}

    (cache, query, callback)->
    
        # TODO: fix
        cache = false

        # fix livescript
        lines = query.split \\n
        lines = [0 til lines.length] 
            |> map (i)-> 
                line = lines[i]
                line = (if i > 0 then "}," else "") + \{ + line if line.0 == \$
                line += \} if i == lines.length - 1
                line

        # compose request object
        request = {
            cache
            query: "[#{lines.join '\n'}]"
        }

        # return cached response (if any)
        return callback previous.err, previous.result if request `is-equal-to-object` previous.request

        query-result-promise = $.post \/query, JSON.stringify request
            ..done (response)->                 
                previous <<< {request, err: null, result: response}
                callback null, response

            ..fail ({response-text}) -> 
                previous <<< {request, err: response-text, result: null}
                callback response-text, null

)!

# 
execute-query-and-display-results = (->

    busy = false

    (document-state)->
    
        return if busy
        busy := true

        # show preloader
        $ \.preloader .show!        

        # query, transform & plot 
        {query, transformation, presentation} = document-state
        
        {cache} = get-hash!        
        (err, result) <- execute-query (!!cache && parse-bool cache), query

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

)!

#
get-document-state = (query-id)->
    {
        query-id
        name: $ \#name .val!
        query: query-editor.get-value!
        transformation: transformation-editor.get-value!
        presentation: presentation-editor.get-value!
    }

# converts the hash query string to object
get-hash = -> 
    (window.location.hash.replace \#?, "").split \& 
        |> map (.split \=) 
        |> pairs-to-obj

#
get-query-id = (->

    result = null

    (url)->
        return result if !!result

        [url, domain, query-id, query-parameters]? = window.location.href.match page-url-regex
        result := parse-int try-get query-id, new Date!.get-time!
)!

#
get-query-parameters = ->
    [url, domain, query-id, query-parameters]? = window.location.href.match page-url-regex
    try-get query-parameters, ""

# returns noop if the document hasn't changed since the last save
get-save-function = (document-state)->

    # if there are no changes to the document return noop as the save function
    return [false, $.noop] if document-state `is-equal-to-object` window.remote-document-state

    # if the document has changed since the last save then 
    # return a function that will POST the new document to the server
    [
        true
        ->        

            # update the local-storage before making the request to recover from unexpected crash
            save-to-local-storage document-state

            (err) <- save-to-server document-state
            return console.log err if !!err

            window.remote-document-state = document-state

    ]

# two objects are equal if they have the same keys & values
is-equal-to-object = (o1, o2)->
    return false if (typeof o1 == \undefined || o1 == null) || (typeof o2 == \undefined || o2 == null)
    (keys o1) |> fold ((memo, key)-> memo && (o2[key] == o1[key])), true

# by default the keymaster plugin filters input elements
key.filter = -> true

# returns dasherized collection of keywords for auto-completion
keywords-from-context = (context)->
    context
        |> obj-to-pairs 
        |> map -> dasherize it.0

# save the document
on-save = (e, document-state)->

    [,save-function] = get-save-function document-state
    save-function!

    # prevent default behavious of displaying the save-dialog
    e.prevent-default!
    e.stop-propagation!
    false

# utility function, converts a string to boolean
parse-bool = -> it == \true

# DRY function used by presentation-context
plot-chart = (chart, result)->
    show-output-tag \svg
    d3.select \svg .datum result .call chart

#
push-state = (query-id)->
    state = if !!(local-storage.get-item query-id) then JSON.parse (local-storage.get-item query-id) else {} <<< window.remote-document-state
    state <<< {query-id}
    history.replace-state state, state.name, "/#{query-id}#{get-query-parameters!}"
    state

# update the ace-editors after there corresponding div elements have been resized
resize-editors = -> [query-editor, transformation-editor, presentation-editor] |> map (.resize!)

# update the size of elements based on editor & window width & height
resize-output = ->
    $ \.output .width window.inner-width - ($ \.editors .width!) - ($ \.resize-handle.vertical .width!)
    $ \.output .height window.inner-height - ($ \.menu .height!)
    $ "pre, svg" .width ($ \.output .width!)
    $ "pre, svg" .height ($ \.output .height!)
    $ \.resize-handle.vertical .height Math.max ($ \.output .height!), ($ \.editors .height!)
    $ \.preloader 
        ..css {left: $ \.output .offset!.left, top: $ \.output .offset!.top}
        ..width ($ \.output .width!)
        ..height ($ \.output .height!)    
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

# 
show-output-tag = (tag)-> 
    $ \.output .children! .each -> 
        $ @ .css \display, if ($ @ .prop \tagName).to-lower-case! == tag then "" else \none

#
try-get = (value, default-value)-> if !!value then value else default-value

#
update-editors = ({name, query, transformation, presentation})->
    $ \#name .val name
    query-editor.set-value query
    transformation-editor.set-value transformation
    presentation-editor.set-value presentation
    [query-editor, transformation-editor, presentation-editor] |> map -> it.session.selection.clear-selection!

# on dom ready
$ ->

    show-output-tag \pre

    # setup the initial size
    $ \.editors .width window.inner-width * 0.4
    $ \.editor .height ((window.inner-height - $ \.menu .height!) - 3 * ($ \.editor-name .height! + $ \.resize-handle.horizontal .height! + 1)) / 3
    resize-output!

    # change the width of the editors & the output
    $ \.resize-handle.vertical .unbind \mousedown .bind \mousedown, (e1)->
        initial-width = $ \.editors .width!

        $ window .unbind \mousemove .bind \mousemove, (e2)->            
            $ \.editors .width (initial-width + (e2.page-x - e1.page-x))
            resize-editors!
            resize-output!

        $ window .unbind \mouseup .bind \mouseup, -> $ window .unbind \mousemove .unbind \mouseup

    # change the height of the editors 
    $ \.resize-handle.horizontal .unbind \mousedown .bind \mousedown, (e1)->
        $editor = $ e1.original-event.current-target .prev-all! .filter \.editor:first
        initial-height = $editor .height!

        $ window .unbind \mousemove .bind \mousemove, (e2)-> 
            $editor.height (initial-height + (e2.page-y - e1.page-y))
            resize-editors!
            resize-output!

        $ window .unbind \mouseup .bind \mouseup, -> $ window .unbind \mousemove .unbind \mouseup

    # resize the chart on window resize
    window.onresize = ->
        resize-output!
        chart.update! if !!chart

    # create the editors
    query-editor := create-livescript-editor \query-editor
    transformation-editor := create-livescript-editor \transformation-editor
    presentation-editor := create-livescript-editor \presentation-editor

    # auto-complete mongo keywords, transformation-context keywords & presentation-context keywords
    lang-tools = ace.require \ace/ext/language_tools
        ..add-completer {
            get-completions: (, , , prefix, callback)->

                mongo-keywords = <[$add $add-to-set $all-elements-true $and $any-element-true $avg $cmp $concat $cond $day-of-month $day-of-week $day-of-year $divide $eq $first $geo-near $group $gt 
                $gte $hour $if-null $last $let $limit $literal $lt $lte $map $match $max $meta $millisecond $min $minute $mod $month $multiply $ne $not $or $out $project $push $redact $second 
                $set-difference $set-equals $set-intersection $set-is-subset $set-union $size $skip $sort $strcasecmp $substr $subtract $sum $to-lower $to-upper $unwind $week $year]>
                
                callback null, convert-to-ace-keywords mongo-keywords, \mongo, prefix
        }
        ..add-completer { get-completions: (, , , prefix, callback)-> callback null, convert-to-ace-keywords (keywords-from-context get-transformation-context!), \transformation, prefix }
        ..add-completer { get-completions: (, , , prefix, callback)-> callback null, convert-to-ace-keywords (keywords-from-context get-presentation-context!), \presentation, prefix }

    # auto complete for mongo collection properties
    $.get \/keywords, (collection-keywords)-> 
        lang-tools.add-completer { get-completions: (, , , prefix, callback)-> callback null, convert-to-ace-keywords (JSON.parse collection-keywords), \collection, prefix }
        
    # load document
    query-id = get-query-id!
    update-editors push-state query-id

    #
    save-to-local-storage get-document-state query-id

    # save to local storage as soon as the user idles for more than half a second after any keydown
    $ window .on \keydown, _.debounce (-> save-to-local-storage get-document-state query-id), 500

    # save to server 
    key 'command + s', (e)-> on-save e, get-document-state query-id
    $ \#save .on \click, (e)-> on-save e, get-document-state query-id

    # execute the query on button click or hot key (command + enter)
    key 'command + enter', -> execute-query-and-display-results get-document-state query-id
    $ \#execute-query .on \click, -> execute-query-and-display-results get-document-state query-id

    # fork
    $ \#fork .on \click, ->
        new-query-id = new Date!.get-time!
        forked-document-state = get-document-state new-query-id
        forked-document-state.name = "Copy of #{forked-document-state.name}"
        local-storage.set-item new-query-id, JSON.stringify forked-document-state
        window.open "http://#{domain}/#{new-query-id}", \_blank

    # prevent loss of work, does not guarantee the completion of async functions    
    window.onbeforeunload = -> 
        save-to-local-storage get-document-state query-id
        [should-save] = get-save-function get-document-state query-id
        return "You have NOT saved your query. Stop and save if your want to keep your query." if should-save

    









































