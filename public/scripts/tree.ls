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

draw-commit-tree = (element, width, height, queries)->

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

                    ..append \button .text "Delete Query" .on \click, ->
                        {query-id} = (svg.select \circle.highlight).datum!
                        err, text <- d3.text "/delete/query/#{query-id}"
                        return console.log err if !!err
                        draw-commit-tree element, width, height, query-id

                    ..append \button .text "Delete Branch" .on \click, ->
                        {branch-id} = (svg.select \circle.highlight).datum!
                        (err, text) <- d3.text "/delete/branch/#{branch-id}"
                        return console.log err if !!err
                        draw-commit-tree element, width, height, query-id

                    ..append \div .attr \style, \clear:both

            ..on \click, ->
                {branch-id, query-id} = (svg.select \circle.highlight).datum!
                window.open "/branch/#{branch-id}/#{query-id}", \_blank

            ..on \mouseleave, ->
                svg.select \circle.highlight .attr \fill, \white
                svg.select-all \.highlight .attr \class, ""
                tooltip .attr \style, "display: none"

    tooltip-keys = [{key: \queryId, name: \Id}, {key: \branchId, name: \Branch}, {key: \queryName, name: \Name}, {key: \creationTime, name: \Date}]

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
resize = -> draw-commit-tree (d3.select \body), window.inner-width, window.inner-height, window.queries
window.onresize = resize
resize!