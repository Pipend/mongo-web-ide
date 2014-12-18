$ = require \jquery-browserify
d3 = require \d3-browserify
{draw-commit-tree} = require \./commit-tree.ls
{dasherize, map, find, filter, fold, group-by, Obj, obj-to-pairs, pairs-to-obj, sort-by, unique, unique-by, values} = require \prelude-ls
{search-queries-by-name, queries-in-same-tree} = require \./queries.ls

# on DOM ready
<- $

die = (err)-> document.body.inner-HTML = "error: #{err}"

draw = (current-query-id, queries)->

    draw-commit-tree do 
        (d3.select \body)
        window.inner-width
        window.inner-height
        queries
        [
            {
                key: \queryId
                name: \Id
            }
            {
                key: \branchId 
                name: \Branch
            }
            {
                key: \queryName
                name: \Name
            }
            {
                key: \creationTime
                name: \Date
            }
        ]
        [
            {
                label: "Delete Query"
                on-click: (query-to-delete)->
                    return if !confirm "Are you sure you want to delete this query"
                    err, parent-query-id <- d3.text "/delete/query/#{query-to-delete.query-id}"
                    return die err if !!err
                    return die "parent-query-id is undefined" if parent-query-id.length == 0
                    new-query-id = if current-query-id == query-to-delete.query-id then parent-query-id else current-query-id
                    history.replace-state {new-query-id}, "#{new-query-id}", "/tree/#{new-query-id}"
                    render false, new-query-id
            }
            {
                label: "Delete Branch"
                on-click: ({branch-id})->
                    return if !confirm "Are you sure you want to delete this branch"
                    (err, parent-query-id) <- d3.text "/delete/branch/#{branch-id}"
                    return die err if !!err
                    return die "parent-query-id is undefined" if parent-query-id.length == 0
                    new-query-id = if !!(queries |> find (query)-> query.branch-id == branch-id and query.query-id == current-query-id) then parent-query-id else current-query-id
                    history.replace-state {new-query-id}, "#{new-query-id}", "/tree/#{new-query-id}"
                    render false, new-query-id
            }            
        ]

fetch-queries = do ->
    cache = null
    (use-cache, query-id, callback) ->
        return callback null, cache if !!use-cache and !!cache
        err, queries <- queries-in-same-tree query-id
        return callback err, null if !!err
        callback null, cache := queries

render = (use-cache, query-id)->
    err, queries <- fetch-queries use-cache, query-id
    return die err if !!err    
    draw query-id, queries

window.onresize = -> render true

render false, window.query-id


