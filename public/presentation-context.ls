{concat-map, map, unique, sort} = require \prelude-ls

window.get-presentation-context = (chart, plot-chart, show-output-tag)->

    # all functions defined here are accessibly by the presentation code
    {

        json: (result)-> 
            show-output-tag \pre
            $ \pre .html JSON.stringify result, null, 4

        table: (result)-> 

            show-output-tag \pre

            cols = result.0 |> Obj.keys |> filter (.index-of \$ != 0)
            
            #todo: don't do this if the table is already present
            $ \pre .html ''
            $table = d3.select \pre .append \table
            $table.append \thead .append \tr
            $table.append \tbody

            $table.select 'thead tr' .select-all \td .data cols
                ..enter!
                    .append \td
                ..exit!.remove!
                ..text id

            
            $table.select \tbody .select-all \tr .data result
                ..enter!
                    .append \tr
                    .attr \style, (.$style)
                ..exit!.remove!
                ..select-all \td .data obj-to-pairs >> (filter ([k]) -> (cols.index-of k) > -1)
                    ..enter!
                        .append \td
                    ..exit!.remove!
                    ..text (.1)

        plot-histogram: (result)->

            <- nv.add-graph

            chart := nv.models.multi-bar-chart!
                .x (.label)
                .y (.value)

            plot-chart chart, result

        plot-timeseries: (result)->

            <- nv.add-graph 

            chart := nv.models.line-chart!
                .x (.0)
                .y (.1)
            chart.x-axis.tick-format (timestamp)-> (d3.time.format \%x) new Date timestamp
            
            plot-chart chart, result
            
        plot-stacked-area: (result, {y-axis-format = (d3.format ',')})->

            <- nv.add-graph 

            all-values = result |> concat-map (.values |> concat-map (.0)) |> unique |> sort
            result := result |> map ({key, values}) ->
                key: key
                values: all-values |> map ((v) -> [v, values |> find (.0 == v) |> (?.1 or 0)])

            chart := nv.models.stacked-area-chart!
                .x (.0)
                .y (.1)
                .useInteractiveGuideline true
                .show-controls true
                .clip-edge true

            chart
                ..x-axis.tick-format (timestamp)-> (d3.time.format \%x) new Date timestamp
                ..y-axis.tick-format y-axis-format
                
            plot-chart chart, result

        plot-scatter: (result, {tooltip, x-axis-format = (d3.format '.02f'), y-axis-format = (d3.format '.02f')}) ->

            <- nv.add-graph

            chart := nv.models.scatter-chart!
                .show-dist-x true
                .show-dist-y true
                .transition-duration 350
                .color d3.scale.category10!.range!

            chart
                ..scatter.only-circles false

                ..tooltip-content (key, , , {point}) -> 
                    (tooltip or (key) -> '<h3>' + key + '</h3>') key, point

                ..x-axis.tick-format x-axis-format
                ..y-axis.tick-format y-axis-format

            plot-chart chart, result
    }