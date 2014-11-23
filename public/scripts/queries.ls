$ = require \../lib/jquery/dist/jquery.js
{map, find, filter, sort-by, unique-by} = require \prelude-ls

search-queries-by-name = (name, callback)->

    request = $.get "/list?name=#{name}"
        ..done (response)->

            queries = JSON.parse response

            local-queries = [0 to local-storage.length] 
                |> map -> local-storage.key it
                |> filter -> !!it
                |> map -> 
                    data = local-storage.get-item it
                    {query-name}? = JSON.parse data
                    {query-id: (parse-int it), query-name}
                |> filter ({query-name})-> !!query-name
                |> filter ({query-id})->
                    server-version = queries |> find -> it.query-id == query-id
                    (typeof server-version == \undefined) || server-version.status

            all-queries = (queries |> filter (.status == true)) ++ local-queries
                |> unique-by (.query-id)
                |> sort-by -> it?.creation-time or 0

            callback null, all-queries
                
        ..fail ({response-text})-> callback response-text, null

module.exports = {search-queries-by-name}
