{map} = require \prelude-ls

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

# temprory measure to prevent loss of work
window.onbeforeunload = -> return "You have NOT saved your query. Stop and save if your want to keep your query."

# on dom ready
$ ->

    # create the editors
    query-editor = create-livescript-editor \editor
    transformer = create-livescript-editor \transformer

    # setup auto-complete
    lang-tools = ace.require \ace/ext/language_tools
    
    execute-query-and-display-results = ->

        $ \#preloader .remove-class \hide

        (err, result) <- execute-query query-editor.get-value!
        if !!err
            $ \#preloader .add-class \hide
            return $ \#result .html "query-editor error #{err}"

        $.post \/transform, JSON.stringify {transformation: transformer.get-value!, result}
            ..done (response)-> $ \#result .html response
            ..fail ({response-text})-> $ \#result .html "transformer error #{response-text}"
            ..always -> $ \#preloader .add-class \hide        


    # execute the query on button click or hot key (command + enter)
    KeyboardJS.on "command + enter", execute-query-and-display-results
    $ \#execute-mongo-query .on \click, execute-query-and-display-results

