{concat-map, map, unique, sort, find} = require \prelude-ls

module.exports = ({Plottable, plot-chart, d3, nv}) -> new Plottable do
    (view, result, {x, y, y-axis, x-axis, show-legend, show-controls, use-interactive-guideline, clip-edge, fill-intervals, key, values}, continuation) !-->

        <- nv.add-graph 

        all-values = result |> concat-map (-> (values it) |> concat-map x) |> unique |> sort
        result := result |> map (d) ->
            key: key d
            values: all-values |> map ((v) -> [v, (values d) |> find (-> (x it) == v) |> (-> if !!it then (y it) else (fill-intervals))])

        chart = nv.models.stacked-area-chart!
            .x x
            .y y
            .use-interactive-guideline use-interactive-guideline
            .show-controls show-controls
            .clip-edge clip-edge
            .show-legend show-legend

        chart
            ..x-axis.tick-format x-axis.tick-format
            ..y-axis.tick-format y-axis.tick-format
        
        plot-chart view, result, chart

        <- continuation chart, result
        
        chart.update!

    {
        x: (.0)
        y: (.1)
        key: (.key)
        values: (.values)
        show-legend: true
        show-controls: true
        clip-edge: true
        fill-intervals: 0
        use-interactive-guideline: true
        y-axis: 
            tick-format: (d3.format ',')
        x-axis: 
            tick-format: (timestamp)-> (d3.time.format \%x) new Date timestamp
    }