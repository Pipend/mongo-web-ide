$ = require \jquery-browserify
d3 = require \d3-browserify
{dasherize, map, find, filter, fold, group-by, Obj, obj-to-pairs, pairs-to-obj, sort-by, unique, unique-by, values} = require \prelude-ls

create-commit-tree-json = (queries, {query-id, branch-id, selected}:query)-->

    children = queries 
        |> filter (.parent-id == query-id) 
        |> map (create-commit-tree-json queries)

    if (children |> filter (.branch-id == branch-id)).length == 0
        children.push [{query-id: null, branch-id, selected: false, children: null}]

    {children} <<< query

draw-commit-tree = (element, width, height, queries, tooltip-keys, tooltip-actions)->

    # compute branch colors
    unique-branches = queries
        |> group-by (.branch-id)
        |> obj-to-pairs
        |> map (.0)
    color-scale = d3.scale.category10!.domain [0 til unique-branches.length]
    branch-colors = [0 til unique-branches.length]
        |> map (i)-> [unique-branches[i], color-scale i]
        |> pairs-to-obj

    tree = d3.layout.tree!.size [width, height]

    # compute tree nodes & links
    json = if !!queries and queries.length >  0 then create-commit-tree-json queries, queries.0 else []

    nodes = tree.nodes json
        |> map ({x, y}: node)->
            node <<< {x: (y / height) * width, y: (x / width) * height}
    links = tree.links nodes

    # create the tooltip
    tooltip = element .select \.tooltip
    if !!tooltip.empty!
        tooltip = element .append \div .attr {class: \tooltip, style: \display:none}
            ..append \div .attr \class, \container
                ..append \div .attr \class, \rows
                ..append \div .attr \class, \controls 

            ..on \mouseleave, ->
                svg.select \circle.highlight .attr \fill, \white
                svg.select-all \.highlight .attr \class, ""
                tooltip .attr \style, "display: none"

    tooltip .select \.controls .select-all \button .data tooltip-actions
        ..enter! .append \button
        ..text ({label})-> label 
        .on \click, ({on-click})-> on-click (d3.select \circle.highlight .datum!)
        ..exit!.remove!

    # plot the tree
    svg = element .select \svg
    svg = element.append \svg if !!svg.empty! 
    svg .attr \width, width .attr \height, height 
        ..select-all \path .data links
            ..enter!.append \path
            ..attr \data-branch-id, (({target: {branch-id}})-> "#branch-id")
            .attr \d, ({source, target})-> "M#{source.x} #{source.y} L#{target.x} #{target.y} Z"
            .attr \opacity, ({source, target})-> if !!target?.children then 1 else 0
            .attr \stroke, (({source, target})-> branch-colors[target.branch-id])
            ..exit!.remove!
        ..select-all \circle .data nodes        
            ..enter!.append \circle            
            ..on \mouseover, ({x, y, branch-id}:query)->

                # highlight the query node & branch                
                (d3.select @).attr \class, \highlight .attr \fill, branch-colors[branch-id]
                d3.select-all "path[data-branch-id=#{branch-id}]" .attr \class, \highlight

                # update the tooltip data
                tooltip .attr \style, "" .select \.rows .select-all \div.row .data (query 
                        |> obj-to-pairs
                        |> map ([key, value])-> [(tooltip-keys |> find -> it.key == key), value]
                        |> filter ([tooltip-key]) -> !!tooltip-key
                        |> map ([{name}, value])->  [name, value])
                    ..enter! .append \div .attr \class, \row
                        ..append \span
                        ..append \span
                    ..select \span:first-child .text (.0)
                    ..select \span:last-child .text (.1)
                    ..exit!.remove!            

                # position the tooltip
                tooltip-width = tooltip.node!.offset-width
                tooltip-height = tooltip.node!.offset-height
                x = if x + (tooltip-width / 2) > width then -2 * tooltip-width / 2 + width else x - tooltip-width / 2
                x = if x < 0 then 0 else x
                if y + tooltip-height > height
                    tooltip .attr \class, "tooltip above" .attr \style, -> "left: #{x}px; top: #{y + 16 - tooltip-height }px;"
                else                 
                    tooltip .attr \class, "tooltip" .attr \style, -> "left: #{x}px; top: #{y - 16}px;"

            .attr \opacity, ({children})-> if !!children then 1 else 0
            .attr \r, ({selected})-> if !!selected then 16 else 8
            .attr \fill, \white
            .attr \stroke, ({branch-id})-> branch-colors[branch-id]
            .attr \transform, (({x, y})-> "translate(#x, #y)")
            ..exit!.remove!

# on DOM ready
<- $

die = (err)-> document.body.inner-HTML = "error: #{err}"

draw = (current-query-id, queries)->

    draw-commit-tree do 
        (d3.select \body)
        window.inner-width
        window.inner-height
        queries
        [{key: \queryId, name: \Id}, {key: \branchId, name: \Branch}, {key: \queryName, name: \Name}, {key: \creationTime, name: \Date}]
        [
            {
                label: "Delete Query"
                on-click: (query-to-delete)->
                    return if !confirm "Are you sure you want to delete this query"
                    err, parent-query-id <- d3.text "/delete/query/#{query-to-delete.query-id}"
                    return die err if !!err
                    return die "parent-query-id is undefined" if parent-query-id.length == 0
                    render false, if current-query-id == query-to-delete.query-id then parent-query-id else current-query-id
            }
            {
                label: "Delete Branch"
                on-click: ({branch-id})->
                    return if !confirm "Are you sure you want to delete this branch"
                    (err, parent-query-id) <- d3.text "/delete/branch/#{branch-id}"
                    return die err if !!err
                    return die "parent-query-id is undefined" if parent-query-id.length == 0
                    render false, if !!(queries |> find (query)-> query.branch-id == branch-id and query.query-id == current-query-id) then parent-query-id else current-query-id
            }
            {
                label: "Preview"
                on-click: ({query-id, branch-id})-> window.open "/branch/#{branch-id}/#{query-id}", \_blank
            }
        ]

fetch-queries = do ->
    cache = null
    (use-cache, query-id, callback) ->
        return callback null, cache if !!use-cache and !!cache
        request = $.getJSON "/queries/tree/#{query-id}"
            ..done (response)-> callback null, cache := response
            ..error ({response-text}) -> callback response-text, null

render = (use-cache, query-id)->
    err, queries <- fetch-queries use-cache, query-id
    return die err if !!err
    history.replace-state {query-id}, "#{query-id}", "/tree/#{query-id}"
    draw query-id, queries

window.resize = -> render true

render false, window.query-id


