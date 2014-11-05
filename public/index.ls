{map} = require \prelude-ls
{compile} = require \LiveScript

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

present-result = (result, presentation-code)->

    json = -> $ \#result .html JSON.stringify result, null, 4

    plot-timeseries = ->

        <- nv.addGraph 

        chart = nv.models.line-chart!
            .x (.0)
            .y (.1)
        chart.x-axis.tick-format (timestamp)-> (d3.time.format \%x) new Date timestamp
            
        d3.select \svg .datum result .call chart

    try 
        eval compile presentation-code, {bare: true}
    catch error
        return error

    return null

transform-result = (result, transformation-code)->

    try 
        transformed-result = eval compile transformation-code, {bare: true}
    catch err
        return [err, null]

    return [null, transformed-result]


# temprory measure to prevent loss of work
window.onbeforeunload = -> return "You have NOT saved your query. Stop and save if your want to keep your query."

# on dom ready
$ ->

    # create the editors
    query-editor = create-livescript-editor \editor
    transformer = create-livescript-editor \transformer
    presenter = create-livescript-editor \presenter

    # setup auto-complete
    lang-tools = ace.require \ace/ext/language_tools
    
    execute-query-and-display-results = ->

        $ \#preloader .remove-class \hide

        (err, result) <- execute-query query-editor.get-value!
        $ \#preloader .add-class \hide
        return $ \#result .html "query-editor error #{err}" if !!err

        [err, result] = transform-result (JSON.parse result), transformer.get-value!
        return $ \#result .html "transformer error #{err}" if !!err

        err = present-result result, presenter.get-value!
        return $ \#result .html "presenter error #{err}" if !!err


    # execute the query on button click or hot key (command + enter)
    KeyboardJS.on "command + enter", execute-query-and-display-results
    $ \#execute-mongo-query .on \click, execute-query-and-display-results

