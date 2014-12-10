$ = require \jquery-browserify
d3 = require \d3-browserify
{map, find, filter, fold, group-by, Obj, obj-to-pairs, pairs-to-obj, sort-by, unique, unique-by, values} = require \prelude-ls

create-commit-tree-json = (queries, {query-id, branch-id, selected})-->

    children = queries 
        |> filter (.parent-id == query-id) 
        |> map (create-commit-tree-json queries)

    if (children |> filter (.branch-id == branch-id)).length == 0
        children.push [{query-id: null, branch-id, selected: false, children: null}]

    {query-id, branch-id, selected, children}

plot-commit-tree = (queries, element, width, height)->

    unique-branches = queries
        |> group-by (.branch-id)
        |> obj-to-pairs
        |> map (.0)

    color-scale = d3.scale.category10!.domain [0 til unique-branches.length]

    branch-colors = [0 til unique-branches.length]
        |> map (i)-> [unique-branches[i], color-scale i]
        |> pairs-to-obj

    width = window.inner-width
    height = window.inner-height
    
    tree = d3.layout.tree!.size [width, height]

    json = create-commit-tree-json queries, queries.0

    nodes = tree.nodes json
        |> map ({x, y}: node)->
            node <<< {x: (y / height) * width, y: (x / width) * height}

    links = tree.links nodes

    element .append \svg .attr \width, width .attr \height, height
        ..select-all \path.link
        .data links
        .enter!
        .append \svg:path
        .attr \class, \link
        .attr \d, ({source, target})-> "M#{source.x} #{source.y} L#{target.x} #{target.y} Z"
        .attr \opacity, ({source, target})-> if !!target?.children then 1 else 0
        .attr \stroke, ({source, target})-> branch-colors[target.branch-id]
        ..select-all \circle.node
        .data nodes
        .enter!
        .append \svg:circle
        .attr \class, \node
        .attr \opacity, ({children})-> if !!children then 1 else 0
        .attr \r, 8
        .attr \fill, ({selected})-> if !!selected then "rgba(0,255,0,0.8)" else \white
        .attr \stroke, ({branch-id})-> branch-colors[branch-id]
        .attr \transform, ({x, y})-> "translate(#x, #y)"
        .on \click, ({branch-id, query-id})-> window.open "/branch/#{branch-id}/#{query-id}", \_blank


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

                # remove queries that do not match search criterion
                |> filter ({query-name})->
                    (query-name.to-lower-case!.trim!.index-of name.to-lower-case!.trim!) != -1

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
                |> map ({query-name}:query)-> 
                    match-index = query-name.to-lower-case!.index-of name.to-lower-case!
                    {} <<< query <<< {match-index}

            callback null, all-queries
                
        ..fail ({response-text})-> callback response-text, null

module.exports = {plot-commit-tree, search-queries-by-name}
