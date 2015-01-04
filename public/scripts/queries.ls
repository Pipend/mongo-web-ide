$ = require \jquery-browserify
d3 = require \d3-browserify
{dasherize, filter, find, fold, group-by, map, Obj, obj-to-pairs, pairs-to-obj, sort-by, unique, unique-by, values} = require \prelude-ls

queries-in-same-tree = (query-id, callback)->
    request = $.getJSON "/queries/tree/#{query-id}"
        ..done (response)-> callback null, response
        ..error ({response-text}) -> callback response-text, null

search-queries-by-name = (name, callback)->

    request = $.get "/list?name=#{name}"
        ..done (response)->

            queries = JSON.parse response
                |> map ({query-name}:query)-> 
                    match-index = query-name.to-lower-case!.index-of name.to-lower-case!
                    {} <<< query <<< {match-index}

            callback null, queries
                
        ..fail ({response-text})-> callback response-text, null

module.exports = {search-queries-by-name, queries-in-same-tree}
