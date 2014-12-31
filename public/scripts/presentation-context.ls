# the first require is used by browserify to import the prelude-ls module
# the second require is defined in the prelude-ls module and exports the object
require \prelude-ls
{concat-map, map, unique, sort, tail, drop} = require \prelude-ls

module.exports.get-presentation-context = ->

    # all functions defined here are accessibly by the presentation code
    {

        layout: (view, direction, ...)->            
            functions = drop 2, Array.prototype.slice.call arguments
            size = 100 / functions.length
            [0  til functions.length]
                |> map (i)->
                    child-view = document.create-element \div
                        ..style <<< {
                            box-sizing: \border-box
                            border-right: '1px solid #ccc'
                            overflow: \auto
                            position: \absolute
                            left: if direction == \horizontal then "#{i * size}%" else "0%"
                            top: if direction == \horizontal then "0%" else "#{i * size}%"
                            width: if direction == \horizontal then "#{size}%" else "100%"
                            height: if direction == \horizontal then "100%" else "#{size}%"
                        }
                    functions[i](child-view)
                    view.append-child child-view

        layout-horizontal: (view, ...)->
            @layout.apply @, [view, \horizontal] ++ tail Array.prototype.slice.call arguments

        layout-vertical: (view, ...)->
            @layout.apply @, [view, \vertical] ++ tail Array.prototype.slice.call arguments

        json: (view, result)-> 

            pre = $ "<pre/>"
            pre.html JSON.stringify result, null, 4
            ($ view).append pre

            # # display the pre tag
            # $ pre .show!
            # $ svg .hide!

            # # update the contents of the pre tag
            # $ pre .html JSON.stringify result, null, 4

        table: (result)-> 

            # display the pre tag
            # $ pre .show!
            # $ svg .hide!

            # cols = result.0 |> Obj.keys |> filter (.index-of \$ != 0)
            
            # #todo: don't do this if the table is already present
            # $ pre .html ''
            # $table = d3.select \pre .append \table
            # $table.append \thead .append \tr
            # $table.append \tbody

            # $table.select 'thead tr' .select-all \td .data cols
            #     ..enter!
            #         .append \td
            #     ..exit!.remove!
            #     ..text id

            
            # $table.select \tbody .select-all \tr .data result
            #     ..enter!
            #         .append \tr
            #         .attr \style, (.$style)
            #     ..exit!.remove!
            #     ..select-all \td .data obj-to-pairs >> (filter ([k]) -> (cols.index-of k) > -1)
            #         ..enter!
            #             .append \td
            #         ..exit!.remove!
            #         ..text (.1)

        plot-histogram: (result)->

            # <- nv.add-graph

            # chart := nv.models.multi-bar-chart!
            #     .x (.label)
            #     .y (.value)

            # # display the svg
            # $ pre .hide!
            # $ svg .show!
            # d3.select \svg .datum result .call chart

        plot-timeseries: (view, result, callback)->            

            <- nv.add-graph             

            chart = nv.models.line-chart!
                .x (.0)
                .y (.1)
            chart.x-axis.tick-format (timestamp)-> (d3.time.format \%x) new Date timestamp
            
            d3.select view .append \svg .datum result .call chart
            
            # update the chart to fit the container            
            chart.update!

            callback null, chart if !!callback
            
        plot-stacked-area: (result, {y-axis-format = (d3.format ',')})->

            # <- nv.add-graph 

            # all-values = result |> concat-map (.values |> concat-map (.0)) |> unique |> sort
            # result := result |> map ({key, values}) ->
            #     key: key
            #     values: all-values |> map ((v) -> [v, values |> find (.0 == v) |> (?.1 or 0)])

            # chart := nv.models.stacked-area-chart!
            #     .x (.0)
            #     .y (.1)
            #     .useInteractiveGuideline true
            #     .show-controls true
            #     .clip-edge true

            # chart
            #     ..x-axis.tick-format (timestamp)-> (d3.time.format \%x) new Date timestamp
            #     ..y-axis.tick-format y-axis-format
            
            # # display the svg
            # $ pre .hide!
            # $ svg .show!
            # d3.select \svg .datum result .call chart

        plot-scatter: (result, {tooltip, x-axis-format = (d3.format '.02f'), y-axis-format = (d3.format '.02f')}) ->

            # <- nv.add-graph

            # chart := nv.models.scatter-chart!
            #     .show-dist-x true
            #     .show-dist-y true
            #     .transition-duration 350
            #     .color d3.scale.category10!.range!

            # chart
            #     ..scatter.only-circles false

            #     ..tooltip-content (key, , , {point}) -> 
            #         (tooltip or (key) -> '<h3>' + key + '</h3>') key, point

            #     ..x-axis.tick-format x-axis-format
            #     ..y-axis.tick-format y-axis-format

            # # display the svg
            # $ pre .hide!
            # $ svg .show!
            # d3.select \svg .datum result .call chart

    }






