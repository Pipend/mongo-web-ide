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

    tooltip-keys = [{key: \queryId, name: \Id}, {key: \branchId, name: \Branch}, {key: \queryName, name: \Name}, {key: \creationTime, name: \Date}]

    tooltip = element .append \div .attr \class, \tooltip .attr \style, \display:none
        ..select-all \div
            .data tooltip-keys
            .enter!
            .append \div
                ..append \span
                ..append \span

    element .append \svg .attr \width, width .attr \height, height
        ..select-all \path.link
        .data links
        .enter!
        .append \svg:path
        .attr \class, ({source, target})-> "link branch-id-#{target.branch-id}"
        .attr \d, ({source, target})-> "M#{source.x} #{source.y} L#{target.x} #{target.y} Z"
        .attr \opacity, ({source, target})-> if !!target?.children then 1 else 0
        .attr \stroke, ({source, target})-> branch-colors[target.branch-id]
        ..select-all \circle.node
        .data nodes
        .enter!
        .append \svg:circle
        .attr \class, ({selected})-> "node " + if selected then "selected" else ""
        .attr \opacity, ({children})-> if !!children then 1 else 0
        .attr \r, ({selected})-> if selected then 12 else 8
        .attr \fill, ({branch-id, selected})-> if selected then branch-colors[branch-id] else \white
        .attr \stroke, ({branch-id})-> branch-colors[branch-id]
        .attr \transform, ({x, y})-> "translate(#x, #y)"
        .on \mouseover, ({x, y, branch-id}:query)->            

            (d3.select @).attr \fill, branch-colors[branch-id]

            d3.select-all ".link.branch-id-#{branch-id}" .attr \class, "link branch-id-#{branch-id} highlight"

            tuples = query 
                |> obj-to-pairs                
                |> filter ([key]) -> !!(tooltip-keys |> find -> it.key == key)

            tooltip
                ..select-all \span:first-child
                    .data do
                        tuples 
                            |> map ([key])-> 
                                tooltip-keys
                                    |> find -> it.key == key
                                    |> (.name)
                    .text -> it
                ..select-all \span:last-child
                    .data (tuples |> map (.1))
                    .text -> it

            # display the tooltip to compute the dimensions
            tooltip .attr \style, -> ""

            # use the dimensions to position the tooltip
            width = tooltip.node!.offset-width
            height = tooltip.node!.offset-height
            x = if x + (width / 2) > window.inner-width then -2 * width / 2 + window.inner-width else x - width / 2
            x = if x < 0 then 0 else x
            y = if y + height > window.inner-height then y - 16 - height else y + 16
            tooltip .attr \style, -> "left: #{x}px; top: #{y}px;"

        .on \mouseout, ({branch-id, selected})->
            (d3.select @).attr \fill, if selected then branch-colors[branch-id] else \white
            d3.select-all ".link.branch-id-#{branch-id}" .attr \class, "link branch-id-#{branch-id}"
            tooltip .attr \style, "display: none"

        .on \click, ({branch-id, query-id})-> window.open "/branch/#{branch-id}/#{query-id}", \_blank

# on DOM ready
<- $
plot-commit-tree window.queries, (d3.select \body), window.inner-width, window.inner-height
