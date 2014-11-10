{dasherize, filter, fold, keys, map, obj-to-pairs, Obj, pairs-to-obj, id} = require \prelude-ls
{compile} = require \LiveScript

# global variables
chart = null

# creates, configures & returns a new instance of ace-editor
create-livescript-editor = (element-id)->
    ace.edit element-id
        ..set-options {enable-basic-autocompletion: true}
        ..set-theme \ace/theme/monokai
        ..set-show-print-margin false
        ..get-session!.set-mode \ace/mode/livescript

# makes a POST request the server and returns the result of the mongo query
# Note: the request is made only if there is a change in the query
execute-query = (->

    previous-request = {}

    (cache, query, callback)->

        return callback previous-request.err, previous-request.result if query == previous-request.query

        lines = query.split \\n
        lines = [0 til lines.length] 
            |> map (i)-> 
                line = lines[i]
                line = (if i > 0 then "}," else "") + \{ + line if line.0 == \$
                line += \} if i == lines.length - 1
                line

        request-body = JSON.stringify {
            cache
            query: "[#{lines.join '\n'}]"
        }

        query-result-promise = $.post \/query, request-body
            ..done (response)-> 
                previous-request <<< {err: null, result: response}
                callback null, response

            ..fail ({response-text}) -> 
                previous-request <<< {err: response-text, result: null}
                callback response-text, null

        previous-request <<< {query}

)!

convert-to-ace-keywords = (keywords, meta, prefix)->
    keywords
        |> map -> {text: it, meta: meta}
        |> filter -> it.text.index-of(prefix) == 0 
        |> map -> {name: it.text, value: it.text, score: 0, meta: it.meta}

# two objects are equal if they have the same keys & values
is-equal-to-object = (o1, o2)-> (keys o1) |> fold ((memo, key)-> memo && (o2[key] == o1[key])), true

# by default the keymaster plugin filters input elements
key.filter = -> true

keywords-from-context = (context)->
    context
        |> obj-to-pairs 
        |> map -> dasherize it.0

parse-bool = -> it == \true

plot-chart = (chart, result)->
    show-output-tag \svg
    d3.select \svg .datum result .call chart

# compiles & executes livescript
run-livescript = (context, result, livescript)-> 
    livescript = "window <<< require 'prelude-ls' \nwindow <<< context \n" + livescript       
    try 
        return [null, eval compile livescript, {bare: true}]
    catch error 
        return [error, null]

# makes a POST request to the server to save the current document-object
save = (document-object, callback)->
    save-request-promise = $.post \/save, JSON.stringify document-object, null, 4
        ..done (response)-> 
            [err, query-id] = JSON.parse response
            return callback err, null if !!err
            callback null, query-id
        ..fail ({response-text})-> callback response-text, null

update-output-width = ->
    $ \.output .width (window.inner-width - ($ \.editors .width!) - ($ \.resize-handler.vertical .width!) - 10)
    $ \.preloader 
        ..css {left: $ \.output .offset!.left, top: $ \.output .offset!.top}
        ..width ($ \.output .width!)
        ..height ($ \.output .height!)
    $ "pre, svg" .width ($ \.output .width!)
    chart.update! if !!chart

show-output-tag = (tag)-> 
    $ \.output .children! .each -> 
        $ @ .css \display, if ($ @ .prop \tagName).to-lower-case! == tag then "" else \none

# all functions defined here are accessibly by the transformation code
transformation-context = {}

# all functions defined here are accessibly by the presentation code
presentation-context = {

    json: (result)-> 
        show-output-tag \pre
        $ \pre .html JSON.stringify result, null, 4

    table: (result)-> 

        show-output-tag \pre

        cols = result.0 |> Obj.keys |> filter (.index-of \$ != 0)
        
        #todo: don't do this if the table is already present
        $ \pre .html ''
        $table = d3.select \pre .append \table
        $table.append \thead .append \tr
        $table.append \tbody

        $table.select 'thead tr' .select-all \td .data cols
            ..enter!
                .append \td
            ..exit!.remove!
            ..text id

        
        $table.select \tbody .select-all \tr .data result
            ..enter!
                .append \tr
                .attr \style, (.$style)
            ..exit!.remove!
            ..select-all \td .data obj-to-pairs >> (filter ([k]) -> (cols.index-of k) > -1)
                ..enter!
                    .append \td
                ..exit!.remove!
                ..text (.1)

    plot-histogram: (result)->

        <- nv.add-graph

        chart := nv.models.multi-bar-chart!
            .x (.label)
            .y (.value)

        plot-chart chart, result

    plot-timeseries: (result)->

        <- nv.add-graph 

        chart := nv.models.line-chart!
            .x (.0)
            .y (.1)
        chart.x-axis.tick-format (timestamp)-> (d3.time.format \%x) new Date timestamp
        
        plot-chart chart, result
        
    plot-stacked-area: (result)->

        <- nv.add-graph 

        chart := nv.models.stacked-area-chart!
            .x (.0)
            .y (.1)
            .useInteractiveGuideline true
            .show-controls true
            .clip-edge true

        chart.x-axis.tick-format (timestamp)-> (d3.time.format \%x) new Date timestamp
            
        plot-chart chart, result

    plot-scatter: (result, {tooltip, x-axis-format = (d3.format '.02f'), y-axis-format = (d3.format '.02f')}) ->

        <- nv.add-graph

        chart := nv.models.scatter-chart!
            .show-dist-x true
            .show-dist-y true
            .transition-duration 350
            .color d3.scale.category10!.range!

        chart
            ..scatter.only-circles false

            ..tooltip-content (key, , , {point}) -> 
                (tooltip or (key) -> '<h3>' + key + '</h3>') key, point

            ..x-axis.tick-format x-axis-format
            ..y-axis.tick-format y-axis-format

        plot-chart chart, result
}

# resize the chart on window resize
nv.utils.window-resize ->
    update-output-width!
    chart.update! if !!chart

get-hash = -> 
    (window.location.hash.replace \#?, "").split \& 
        |> map (.split \=) 
        |> pairs-to-obj

set-hash = (obj)->
    window.location.hash = obj  
        |> obj-to-pairs 
        |> map (.join \=)
        |> (.join \&)
        |> -> "#?#{it}"

should-cache = ->
    {cache} = get-hash!    
    if typeof cache == \undefined then true else parse-bool cache

# on dom ready
$ ->
    
    # setup the initial size
    $ \.content .height window.inner-height - ($ \.menu .height!)
    $ \.editors .width window.inner-width * 0.4
    $ \.editor .height ($ \.content .height! - 3 * ($ \.editor-name .height! + $ \.resize-handle.horizontal .height! + 1)) / 3    
    $ \.output .height ($ \.content .height!)    
    $ "pre, svg" .height ($ \.output .height!)
    update-output-width!    

    # control server-side caching with document hash
    on-hash-change = -> $ \#cache .toggle-class \on, should-cache!
    window.onhashchange = on-hash-change
    on-hash-change!        

    $ \#cache .on \click, -> set-hash get-hash! <<< {cache: !should-cache!}

    # create the editors
    query-editor = create-livescript-editor \query-editor
    transformer = create-livescript-editor \transformer
    presenter = create-livescript-editor \presenter

    execute-query-and-display-results = ->
        
        # show preloader
        $ \.preloader .show!        

        # query, transform & plot 
        {query, transformation-code, presentation-code} = get-document!

        (err, result) <- execute-query should-cache!, query

        # clear existing result
        $ \pre .html ""
        $ "svg" .empty!

        display-error = (err)->
            show-output-tag \pre
            $ \pre .html err

        # display the new result
        $ \.preloader .hide!
        return display-error "query-editor error #{err}" if !!err

        [err, result] = run-livescript transformation-context, (JSON.parse result), transformation-code
        return display-error "transformer error #{err}" if !!err

        [err, result] = run-livescript presentation-context, result, presentation-code
        return display-error "presenter error #{err}" if !!err

    get-document = -> {
        query-id: window.document-properties.query-id
        name: $ \#name .val!
        query: query-editor.get-value!
        transformation-code: transformer.get-value!
        presentation-code: presenter.get-value!
    }

    # returns noop if the document hasn't changed since the last save
    get-save-function = (->        
        last-saved-document = if document-properties.query-id is null then {} else get-document!
        -> 

            # if there are no changes to the document return noop as the save function
            current-document = get-document!
            return [false, $.noop] if current-document `is-equal-to-object` last-saved-document

            # if the document has changed since the last save then 
            # return a function that will POST the new document to the server
            [
                true
                ->        

                    # update the local-storage before making the request to recover from unexpected crash
                    save-to-local-storage!

                    (err, query-id) <- save current-document
                    return console.log err if !!err

                    last-saved-document := current-document

                    if window.document-properties.query-id is null
                        window.onbeforeunload = $.noop!
                        window.location.href += "#{query-id}"
            ]
    )!

    save-to-local-storage = -> 
        local-storage.set-item (document-properties.query-id || 0), JSON.stringify get-document!

    # load from local storage
    local-save = local-storage.get-item (document-properties.query-id || 0)

    if !!local-save
        {query, transformation-code, presentation-code} = JSON.parse local-save
        query-editor .set-value query
        transformer .set-value transformation-code
        presenter .set-value presentation-code
        [query-editor, transformer, presenter] |> map -> it.session.selection.clear-selection!        

    else 
        save-to-local-storage!

    # save as soon as the user idles for more than half a second after keydown
    $ window .on \keydown, _.debounce save-to-local-storage, 500

    # change the width of the editors & the output
    $ \.resize-handle.vertical .unbind \mousedown .bind \mousedown, (e1)->
        initial-width = $ \.editors .width!

        $ window .unbind \mousemove .bind \mousemove, (e2)->            
            $ \.editors .width (initial-width + (e2.page-x - e1.page-x))
            [query-editor, transformer, presenter] |> map (.resize!)
            update-output-width!            

        $ window .unbind \mouseup .bind \mouseup, -> $ window .unbind \mousemove .unbind \mouseup

    # change the height of the editors 
    $ \.resize-handle.horizontal .unbind \mousedown .bind \mousedown, (e1)->
        $editor = $ e1.original-event.current-target .prev-all! .filter \.editor:first
        initial-height = $editor .height!

        $ window .unbind \mousemove .bind \mousemove, (e2)-> 
            $editor.height (initial-height + (e2.page-y - e1.page-y))
            [query-editor, transformer, presenter] |> map (.resize!)

        $ window .unbind \mouseup .bind \mouseup, -> $ window .unbind \mousemove .unbind \mouseup
    
    # auto complete for mongo keywords
    lang-tools = ace.require \ace/ext/language_tools
        ..add-completer {
            get-completions: (, , , prefix, callback)->

                mongo-keywords = <[$add $add-to-set $all-elements-true $and $any-element-true $avg $cmp $concat $cond $day-of-month $day-of-week $day-of-year $divide $eq $first $geo-near $group $gt 
                $gte $hour $if-null $last $let $limit $literal $lt $lte $map $match $max $meta $millisecond $min $minute $mod $month $multiply $ne $not $or $out $project $push $redact $second 
                $set-difference $set-equals $set-intersection $set-is-subset $set-union $size $skip $sort $strcasecmp $substr $subtract $sum $to-lower $to-upper $unwind $week $year]>
                
                callback null, convert-to-ace-keywords mongo-keywords, \mongo, prefix
        }
        ..add-completer { get-completions: (, , , prefix, callback)-> callback null, convert-to-ace-keywords (keywords-from-context transformation-context), \transformation, prefix }
        ..add-completer { get-completions: (, , , prefix, callback)-> callback null, convert-to-ace-keywords (keywords-from-context presentation-context), \presentation, prefix }

    # auto complete for collection properties
    $.get \/keywords, (collection-keywords)->
        lang-tools.add-completer { 
            get-completions: (, , , prefix, callback)-> 
                callback null, convert-to-ace-keywords (JSON.parse collection-keywords), \collection, prefix 
        }

    # execute the query on button click or hot key (command + enter)
    key 'command + enter', execute-query-and-display-results
    $ \#execute-query .on \click, execute-query-and-display-results

    # save the document
    on-save = (e)->

        [,save-function] = get-save-function!
        save-function!

        # prevent default behavious of displaying the save-dialog
        e.prevent-default!
        e.stop-propagation!
        false
    key 'command + s', on-save
    $ \#save .click on-save

    # prevent loss of work, does not guarantee the completion of async functions    
    window.onbeforeunload = -> 
        save-to-local-storage!
        [should-save] = get-save-function!
        return "You have NOT saved your query. Stop and save if your want to keep your query." if should-save

    {execute-on-load} = get-hash!
    execute-query-and-display-results! if parse-bool execute-on-load



