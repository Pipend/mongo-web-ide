{map} = require \prelude-ls

<- $ 
    
lang-tools = ace.require \ace/ext/language_tools

editor = ace.edit \editor
    ..set-options {enable-basic-autocompletion: true}
    ..set-theme \ace/theme/monokai
    ..get-session!.set-mode \ace/mode/livescript

$ "[id=execute-mongo-query]" .on \click, (e)->

    lines = editor.get-value!.split \\n

    lines = [0 til lines.length] 
        |> map (i)-> 
            line = lines[i]
            line = (if i > 0 then "}," else "") + \{ + line if line.0 == \$
            line += \} if i == lines.length - 1
            line

    (res) <- $.post \/query, "[#{lines.join '\n'}]"
    $ "[id=result]" .html res
            

