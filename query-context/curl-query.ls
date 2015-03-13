{id, concat-map, dasherize, difference, each, filter, find, find-index, foldr1, Obj, keys, map, obj-to-pairs, pairs-to-obj, Str, unique, any} = require \prelude-ls
{compile-and-execute-livescript, get-all-keys-recursively} = require \./../utils
{exec} = require \shelljs

export get-query-context = ->
    {} <<< (require \./default-query-context.ls)! <<< (require \prelude-ls)

export query = (connection, query, parameters, query-id, callback) !->
    console.log \---------
    console.log query
    console.log \---------

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


    cmd = "curl #url #{options}"

    code, output <- exec cmd, silent: true

    return callback Error "Error in curl #code #output", null if code != 0

    try
      json = JSON.parse output
    catch error
        return callback error, null
      
    callback null, json

export cancel = (query-id, callback) !->
    callback Error "Not Implemented", null

export keywords = (connection, callback) -->
    console.log callback
    callback null, ["curl", "-H", "-d", "-X", "POST", "GET", "--user", "http://", "https://"]

# err, res <- query do
#     null
#     """
#         curl 
#         "http://207.97.212.169:3033"
#         -s --connect-timeout 60 
#         -H "pretty: 1" 
#         --max-time 60 
#          -H "Content-Type: text/sql"
#         -X POST 
#         -d "
#             SELECT TOP 1 * 
#             FROM WAP_Visits ORDER BY 1 DESC
#         "
#     """
#     {}
#     1

# console.log err, res

# return

# <- query do
#     null
#     """
#         curl
#         --limit-rate 200k 
#         --connect-timeout 2 
#         --max-time 10 
#         --max-filesize 100000 
#         -s 
#         --user "078735bc:a6028e865466e9299cc639e944e5dbc78c0fb8cc" 
#         "https://hub.celtra.com/api/analytics?metrics=sessions,creativeLoads,creativeViews00,sessionsWithInteraction,interactions&dimensions=campaignName,creativeId,creativeName,supplierName&filters.accountDate.gte=2015-02-10&filters.accountDate.lte=2015-02-19&filters.accountId=e97de0f9&sort=-sessions&limit=200"
#     """
#     {}
#     1