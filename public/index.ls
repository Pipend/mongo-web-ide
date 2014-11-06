{map} = require \prelude-ls
{compile} = require \LiveScript

transformation-context = {

}

presentation-context = {

    json: (result)-> $ \#result .html JSON.stringify result, null, 4

    plot-timeseries: (result)->

        <- nv.addGraph 

        chart = nv.models.line-chart!
            .x (.0)
            .y (.1)
        chart.x-axis.tick-format (timestamp)-> (d3.time.format \%x) new Date timestamp
            
        d3.select \svg .datum result .call chart

}

create-livescript-editor = (element-id)->
    ace.edit element-id
        ..set-options {enable-basic-autocompletion: true}
        ..set-theme \ace/theme/monokai
        ..get-session!.set-mode \ace/mode/livescript

execute-query = (query, callback)->

    lines = query.split \\n

    lines = [0 til lines.length] 
        |> map (i)-> 
            line = lines[i]
            line = (if i > 0 then "}," else "") + \{ + line if line.0 == \$
            line += \} if i == lines.length - 1
            line

    query-result-promise = $.post \/query, "[#{lines.join '\n'}]"
        ..done (response)-> callback null, response
        ..fail ({response-text}) -> callback response-text, null

run-livescript = (context, result, livescript)-> 
    livescript = "window <<< require 'prelude-ls' \nwindow <<< context \n" + livescript       
    try 
        return [null, eval compile livescript, {bare: true}]
    catch error 
        return [error, null]

save = (document-object, callback)->
    save-request-promise = $.post \/save, JSON.stringify document-object
        ..done (response)-> 
            [err, query-id] = JSON.parse response
            return callback err, null if !!err
            callback null, query-id
        ..fail ({response-text})-> callback response-text, null
            

# temprory measure to prevent loss of work
window.onbeforeunload = -> return "You have NOT saved your query. Stop and save if your want to keep your query."

# on dom ready
$ ->

    # create the editors
    query-editor = create-livescript-editor \query-editor
    transformer = create-livescript-editor \transformer
    presenter = create-livescript-editor \presenter

    # setup auto-complete
    lang-tools = ace.require \ace/ext/language_tools    

    execute-query-and-display-results = ->

        $ \#preloader .remove-class \hide
        $ \#result .html ""
        $ "svg" .empty!

        {query, transformation-code, presentation-code} = get-document!

        (err, result) <- execute-query query
        $ \#preloader .add-class \hide
        return $ \#result .html "query-editor error #{err}" if !!err

        [err, result] = run-livescript transformation-context, (JSON.parse result), transformation-code
        return $ \#result .html "transformer error #{err}" if !!err

        [err, result] = run-livescript presentation-context, result, presentation-code
        return $ \#result .html "presenter error #{err}" if !!err

    get-document = -> {query-id: window.document-properties.query-id, query: query-editor.get-value!, transformation-code: transformer.get-value!, presentation-code: presenter.get-value!}

    auto-save = ->
        (err, query-id) <- save get-document!
        console.log err if !!err        
        set-timeout auto-save, 5000

    # auto save the document if it has a query-id
    set-timeout auto-save, 5000 if !!document-properties.query-id

    # execute the query on button click or hot key (command + enter)
    KeyboardJS.on "command + enter", execute-query-and-display-results
    $ \#execute-mongo-query .on \click, execute-query-and-display-results

    # save the document
    KeyboardJS.on "command + s", (e)->        
        save get-document!, (err, query-id) -> 
            return if !!err
            if window.document-properties.query-id is null
                window.onbeforeunload = $.noop!
                window.location.href += "#{query-id}"
        e.prevent-default!
        e.stop-propagation!
        return false




