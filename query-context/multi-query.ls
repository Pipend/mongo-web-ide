{id, concat-map, dasherize, difference, each, filter, find, find-index, foldr1, Obj, keys, map, obj-to-pairs, pairs-to-obj, Str, unique, any} = require \prelude-ls
{compile-and-execute-livescript, get-all-keys-recursively} = require \./../utils

export get-query-context = ->
    {object-id-from-date, date-from-object-id} = require \./../public/scripts/utils.ls
    {} <<< (require \./default-query-context.ls)! <<< {object-id-from-date, date-from-object-id} <<< (require \prelude-ls)

export query = ({query-database, execute-query}:connection, query, parameters, query-id, callback) !->
    {get-latest-query-in-branch, get-query-by-id} = require \./../utils
    execute-and-transform-query = (require \./../utils.ls).execute-and-transform-query query-database, execute-query

    query-context = get-query-context! <<< (require \prelude-ls) <<< parameters

    code = """
(cb) ->
    fail = (err) !-> cb err, null
    done = (res) !-> cb null, res

#{query |> Str.lines |> map (-> "    " + it) |> Str.unlines}
            """

    run-latest-query = (branch-id, parameters, _callback) ->

        err, document <- get-latest-query-in-branch query-database, branch-id

        return _callback err, null if !!err
        return _callback "Branch not found #{branch-id}" if !branch-id

        execute-and-transform-query (document <<< {parameters}), _callback

    [err, transpiled-code] = compile-and-execute-livescript do
        code
        {} <<< query-context <<< {

            run-query: (query-id, parameters, callback)-> 

                err, document <- get-query-by-id query-database, query-id
                return callback err, null if !!err

                execute-and-transform-query (document <<< {parameters}), callback

            run-latest-query

            # deprecated
            run-queryb: run-latest-query

        }

    return callback err, null if !!err   

    try 
        err, result <- transpiled-code!
        return callback err, null if !!err
        callback null, result

    catch err
        callback err, null

export cancel = (query-id, callback) !->
    callback "Not implemented", null

export keywords = ({query-database}:connection, callback) -->
    callback null, [\run-latest-query, \run-query]