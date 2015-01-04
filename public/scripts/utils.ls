# the first require is used by browserify to import the LiveScript module
# the second require is defined in the LiveScript module and exports the object
require \LiveScript
{compile} = require \LiveScript

# the first require is used by browserify to import the prelude-ls module
# the second require is defined in the prelude-ls module and exports the object
require \prelude-ls
{keys, map, Str} = require \prelude-ls


module.exports.compile-and-execute-livescript = (livescript-code, context)->

    die = (err)->
        [err, null]

    try 
        js = compile do 
            """
            f = ({#{keys context |> Str.join \,}}:context)->
            #{livescript-code |> Str.lines |> map (-> "    " + it) |> Str.unlines}
            f context
            """
            {bare: true}
    catch err
        return die "livescript transpilation error: #{err.to-string!}"

    try 
        result = eval js
    catch err
        return die "javascript runtime error: #{err.to-string!}"

    [null, result]
