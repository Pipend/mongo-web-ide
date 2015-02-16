{map, id} = require \prelude-ls
{fill-intervals} = require \./_utils.ls
fill-intervals-f = fill-intervals

module.exports = ({Plottable, d3, plot-chart, nv}) -> new Plottable do
    (view, result, {x-label, x, y, x-axis, y-axis, key, values, fill-intervals}:options, continuation) !-->

        <- nv.add-graph

        result := result |> map -> {
            key: (key it)
            values: (values it) 
                |> map (-> [(x it), (y it)]) 
                |> if fill-intervals is not false then (-> fill-intervals-f it, if fill-intervals is true then 0 else fill-intervals) else id
        }

        chart = nv.models.line-chart!.x (.0) .y (.1)
            ..x-axis.tick-format x-axis.format
            ..y-axis.tick-format y-axis.format

        <- continuation chart, result

        plot-chart view, result, chart

        chart.update!

    {
        fill-intervals: false
        key: (.key)
        values: (.values)

        x: (.0)
        x-axis: 
            format: (timestamp) -> (d3.time.format \%x) new Date timestamp
            label: 'time'

        y: (.1)
        y-axis:
            format: id
            label: 'Y'

    }