{map} = require \prelude-ls

module.exports = ({Plottable, nv, plot-chart}) -> new Plottable do 
    (view, result, {x, y, key, values, transition-duration, reduce-x-ticks, rotate-labels, show-controls, group-spacing, show-legend}, continuation) !-->

        <- nv.add-graph

        result := result |> map (-> {key: (key it), values: (values it)})

        chart = nv.models.multi-bar-chart!
            .x x
            .y y
            .transition-duration transition-duration
            .reduce-x-ticks reduce-x-ticks
            .rotate-labels rotate-labels
            .show-controls show-controls
            .group-spacing group-spacing
            .show-legend show-legend

        plot-chart view, result, chart
        
        chart.update!

    {
        key: (.key)
        values: (.values)
        x: (.0)
        y: (.1)
        transition-duration: 300
        reduce-x-ticks: false # If 'false', every single x-axis tick label will be rendered.
        rotate-labels: 0 # Angle to rotate x-axis labels.
        show-controls: true
        group-spacing: 0.1 # Distance between each group of bars.
        show-legend: true

    }