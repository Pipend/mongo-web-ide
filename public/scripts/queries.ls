$ = require \jquery-browserify
{map, find, filter, fold, group-by, Obj, obj-to-pairs, sort-by, unique, unique-by, values} = require \prelude-ls

search-queries-by-name = (name, callback)->

    request = $.get "/list?name=#{name}"
        ..done (response)->

            queries = JSON.parse response

            local-queries = [0 to local-storage.length] 

                # convert index to local-storage key
                |> map -> local-storage.key it

                # remove undefined or null keys
                |> filter -> !!it

                # get JSON data stored in local-storage key
                |> map -> 
                    data = local-storage.get-item it
                    {query-name}? = JSON.parse data
                    {query-id: (parse-int it), query-name, storage: <[local-storage]>}

                # remove local-queries without a name
                |> filter ({query-name})-> !!query-name

                # remove local-queries that have been deleted on the server
                |> filter ({query-id})->
                    server-version = queries |> find -> it.query-id == query-id
                    (typeof server-version == \undefined) || server-version.status

            # remove queries that have been deleted
            server-queries = queries
                |> filter (.status == true)
                |> map -> {} <<< it <<< {storage: <[server]>}

            # merge local & server queries 
            # local-query data overrides server-query data
            # query.storage becomes a collection of places where the query is stored
            all-queries = server-queries ++ local-queries
                |> group-by (.query-id)
                |> obj-to-pairs
                |> map (.1)
                |> map (queries)-> 
                    [query, storage] = queries |> fold ((m, v)->
                        m.0 = v if v.storage.0 is \local or m.0 is null
                        m.1 = m.1 ++ v.storage |> unique
                        m
                    ), [null, []]
                    query <<< {storage}

            callback null, all-queries
                
        ..fail ({response-text})-> callback response-text, null

module.exports = {search-queries-by-name}
