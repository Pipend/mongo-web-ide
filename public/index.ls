{map} = require \prelude-ls

execute-query = (query, callback)->

    lines = query.split \\n

    lines = [0 til lines.length] 
        |> map (i)-> 
            line = lines[i]
            line = (if i > 0 then "}," else "") + \{ + line if line.0 == \$
            line += \} if i == lines.length - 1
            line

    (response) <- $.post \/query, "[#{lines.join '\n'}]"
    callback response

# temprory measure to prevent loss of work
window.onbeforeunload = -> return "You have NOT saved your query. Stop and save if your want to keep your query."

# on dom ready
$ ->

    # create a new ACE Editor instance    
    editor = ace.edit \editor
        ..set-options {enable-basic-autocompletion: true}
        ..set-theme \ace/theme/monokai
        ..get-session!.set-mode \ace/mode/livescript

    # setup auto-complete
    lang-tools = ace.require \ace/ext/language_tools

    # execute the query on button click or hot key (command + enter)
    execute-query-and-display-results = ->
        $ \#preloader .remove-class \hide
        (result) <- execute-query editor.get-value!
        $ \#preloader .add-class \hide
        $ \#result .html result
    KeyboardJS.on "command + enter", execute-query-and-display-results
    $ \#execute-mongo-query .on \click, execute-query-and-display-results

