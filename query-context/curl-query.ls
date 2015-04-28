{id, concat-map, dasherize, difference, each, filter, find, find-index, foldr1, Obj, keys, map, obj-to-pairs, pairs-to-obj, Str, unique, any} = require \prelude-ls
{compile-and-execute-livescript, get-all-keys-recursively} = require \./../utils
{exec} = require \shelljs

poll = {}

export get-query-context = ->
    {} <<< (require \./default-query-context.ls)! <<< (require \prelude-ls)

export query = (connection, query, parameters, query-id, callback) !->

    {shell-command, parse} = require \./../query-context/shell-command-parser

    result = parse shell-command, query

    return callback "Parsing Error #{result.0.1}" if !!result.0.1

    result := result.0.0.args |> concat-map id
    url = result |> find (-> !!it.opt) |> (.opt)
    options = result 
        |> filter (-> !!it.name) 
        |> map ({name, value}) -> 
            (if name.length > 1 then "--" else "-") + name + if !!value then " #value" else ""
        |> Str.join " "

    [err, url] = compile-and-execute-livescript url, parameters
    return callback (Error "Url foramtting failed\n#err", err), null if !!err


    cmd = "curl -s #url #{options}"

    process = exec cmd, silent: true, (code, output) ->

        return callback Error "query was killed #{query-id}" if !poll[query-id]
        delete poll[query-id]

        return callback Error "Error in curl #code #output", null if code != 0

        try
          json = JSON.parse output
        catch error 
            return callback error, null
          
        callback null, json

    poll[query-id] = {
        kill: (kill-callback) ->
            killed = process.kill!
            delete poll[query-id]
            kill-callback null, if killed then \killed else "Already killed"
            
    }

export cancel = (query-id, callback) !-->
    query = poll[query-id]
    return callback (new Error "Query not found #{query-id}") if !query
    query.kill callback

export keywords = (connection, callback) -->
    console.log callback
    callback null, ["curl", "-H", "-d", "-X", "POST", "GET", "--user", "http://", "https://"]

