# the first require is used by browserify to import the prelude-ls module
# the second require is defined in the prelude-ls module and exports the object
require \prelude-ls
{Obj, Str, id, any, average, concat-map, drop, each, filter, find, foldr1, foldl, map, maximum, minimum, obj-to-pairs, pairs-to-obj, sort, sum, tail, take, unique} = require \prelude-ls

# [[key, val]] -> [[key, val]]
fill-intervals = (v, default-value = 0) ->

    gcd = (a, b) -> match b
        | 0 => a
        | _ => gcd b, (a % b)

    x-scale = v |> map (.0)
    x-step = x-scale |> foldr1 gcd
    max-x-scale = maximum x-scale
    min-x-scale = minimum x-scale
    [0 to (max-x-scale - min-x-scale) / x-step]
        |> map (i)->
            x-value = min-x-scale + x-step * i
            [, y-value]? = v |> find ([x])-> x == x-value
            [x-value, y-value or default-value]

# recursively extend a with b
rextend = (a, b) -->
    btype = typeof! b

    return b if any (== btype), <[Boolean Number String Function]>
    return b if a is null or (\Undefined == typeof! a)

    bkeys = Obj.keys b
    return a if bkeys.length == 0
    bkeys |> each (key) ->
        a[key] = a[key] `rextend` b[key]
    a


# Plottable is a monad, run it by plot funciton
class Plottable
    (@plotter, @options = {}, @continuations = ((..., callback) -> callback null), @projection = id) ->
    _plotter: (view, result) ~>
        @plotter view, (@projection result, @options), @options, @continuations

# Runs a Plottable
plot = (p, view, result) -->
    p._plotter view, result


download_ = (f, type, result) -->
    blob = new Blob [f result], type: type
    a = document.create-element \a
    url = window.URL.create-objectURL blob
    a.href = url
    a.download = "file.json"
    document.body.append-child a
    a.click!
    window.URL.revoke-objectURL url


json-to-csv = (obj) ->
    cols = obj.0 |> Obj.keys
    (cols |> (Str.join \,)) + "\n" + do ->
        obj
            |> foldl do
                (acc, a) ->
                    acc.push <| cols |> (map (c) -> a[c]) |> Str.join \,
                    acc
                []
            |> Str.join "\n"

# Attaches options to a Plottable
with-options = (p, o) ->
  new Plottable do
    p.plotter
    {} `rextend` p.options `rextend` o
    p.continuations
    p.projection
 
 
acompose = (f, g) --> (chart, callback) ->
  err, fchart <- f chart
  return callback err, null if !!err
  g fchart, callback
 
 
amore = (p, c) ->
  new Plottable do
    p.plotter
    {} `rextend` p.options
    c
    p.projection
 
 
more = (p, c) ->
  new Plottable do
    p.plotter
    {} `rextend` p.options
    (...init, callback) -> 
      try 
        c ...init
      catch ex
        return callback ex
      callback null
    p.projection
 

# projects the data of a Plottable with f
project = (f, p) -->
  new Plottable do
    p.plotter
    p.options
    p.continuations
    (data, options) -> 
        fdata = f data, options
        p.projection fdata, options


# wraps a Plottable in a cell (used in layout)
cell = (plotter) -> {plotter}

# wraps a Plottable in cell that has a size (used in layout)
scell = (size, plotter) -> {size, plotter}


module.exports.get-presentation-context = ->

    layout = (direction, cells) --> 
        if "Array" != typeof! cells
            cells := drop 1, [].slice.call arguments

        new Plottable (view, result, options, continuation) !-->
            child-view-sizes = cells |> map ({size, plotter}) ->
                    child-view = document.create-element \div
                        ..style <<< {                            
                            overflow: \auto
                            position: \absolute                            
                        }
                        ..class-name = direction
                    view.append-child child-view
                    plot plotter, child-view, result
                    {size, child-view}

            sizes = child-view-sizes 
                |> map (.size)
                |> filter (size) -> !!size and typeof! size == \Number

            default-size = (1 - (sum sizes)) / (child-view-sizes.length - sizes.length)

            child-view-sizes = child-view-sizes |> map ({child-view, size})-> {child-view, size: (size or default-size)}
                
            [0 til child-view-sizes.length]
                |> each (i)->
                    {child-view, size} = child-view-sizes[i]                    
                    position = take i, child-view-sizes
                        |> map ({size})-> size
                        |> sum
                    child-view.style <<< {
                        left: if direction == \horizontal then "#{position * 100}%" else "0%"
                        top: if direction == \horizontal then "0%" else "#{position * 100}%"
                        width: if direction == \horizontal then "#{size * 100}%" else "100%"
                        height: if direction == \horizontal then "100%" else "#{size * 100}%"
                    }


    download-mime_ = (type, result) -->
        [f, mime, g] = match type
            | \json => [(-> JSON.stringify it, null, 4), \text/json, json]
            | \csv => [json-to-csv, \text/csv, csv]
        download_ f, mime, result
        g

    download-and-plot = (type, p, view, result) -->
        download-mime_ type, result
        (plot p) view, result

    download = (type, view, result) -->
        g = download-mime_ type, result
        g view, result


    json = (view, result) !--> 
        pre = $ "<pre/>"
            ..html JSON.stringify result, null, 4
        ($ view).append pre

    csv = (view, result) !-->
        pre = $ "<pre/>"
            ..html json-to-csv result
        ($ view).append pre

    plot-chart = (view, result, chart)->
        d3.select view .append \div .attr \style, "position: absolute; left: 0px; top: 0px; width: 100%; height: 100%" .append \svg .datum result .call chart        

        
    fill-intervals-f = fill-intervals


    histogram = new Plottable do 
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


    scatter = new Plottable do 
        (view, result, {tooltip, show-legend, color, transition-duration, x, y, x-axis, y-axis, margin}, continuation)!->

            <- nv.add-graph

            chart = nv.models.scatter-chart!
                .show-dist-x x-axis.show-dist
                .show-dist-y y-axis.show-dist
                .transition-duration transition-duration
                .color color
                .show-dist-x x-axis.show-dist
                .show-dist-y y-axis.show-dist
                .x x
                .y y
                .margin margin


            chart
                ..scatter.only-circles false

                ..tooltip-content (key, , , {point}) -> 
                    tooltip key, point

                ..x-axis.tick-format x-axis.format
                ..y-axis.tick-format y-axis.format

            chart.show-legend show-legend
            plot-chart view, result, chart
            

            <- continuation chart, result
            
            chart.update!

        {
            tooltip: (key, point) -> '<h3>' + key + '</h3>'
            show-legend: true
            transition-duration: 350
            color: d3.scale.category10!.range!
            x-axis:
                format: d3.format '.02f'
                show-dist: true
            x: (.x)

            y-axis:
                format: d3.format '.02f'
                show-dist: true
            y: (.y)
            margin: {top: 30, right: 20, bottom: 50, left: 75}

        }         


    correlation-matrix = new Plottable do
        (view, result, {traits, category}, continuation) !->

            if !traits
                traits := Obj.keys result.0

            if !category
                category := -> "any-category"


            width = view.client-width
            padding = 10
            n = traits.length
            size = (width - (n * padding)) / n

            x = d3.scale.linear!.range [padding / 2, size - padding / 2]
            y = d3.scale.linear!.range [size - padding / 2, padding / 2]

            x-axis = d3.svg.axis!
                .scale x
                .orient \bottom
                .ticks 5
                .tick-size size * n

            y-axis = d3.svg.axis!
                .scale y
                .orient \left
                .ticks 5
                .tick-size -1 * size * n


            color = d3.scale.category10!


            domain-by-trait = traits |> (map (t) -> [t, (d3.extent result, (d) -> d[t])]) >> pairs-to-obj


            cross = (a, b) -->
                [{i, j, x: a[i], y: b[j] } for i in [0 to a.length - 1] for j in [0 to b.length - 1]]


            plot = (p) ->
                cell = d3.select this

                x.domain domain-by-trait[p.x]
                y.domain domain-by-trait[p.y]

                cell.append \rect
                    .attr \class, \frame
                    .attr \x, padding / 2
                    .attr \y, padding / 2
                    .attr \width, size - padding
                    .attr \height, size - padding

                cell.select-all \circle
                    .data result
                    .enter!.append \circle
                    .attr "cx", (d) -> x d[p.x]
                    .attr "cy", (d) -> y d[p.y]
                    .attr "r", 3
                    .style "fill", (d) -> color (category d)


            svg = d3.select view .append \svg
                .attr \class, \correlation-matrix
                .attr \width, size * n + padding
                .attr \height, size * n + padding
                .append \g
                .attr \transform, "translate(" + padding + "," + padding / 2 + ")"

            svg.select-all \.x.axis
                .data traits
                .enter!.append \g
                .attr \class, 'x axis'
                .attr \transform, (d, i) -> "translate(" + (n - i - 1) * size + ",0)"
                .each (d) -> 
                    x.domain domain-by-trait[d]
                    d3.select this .call x-axis

            svg.select-all \.y.axis
                .data traits
                .enter!.append \g
                .attr \class, 'y axis'
                .attr \transform, (d, i) -> "translate(0," + i * size + ")"
                .each (d) ->
                    y.domain domain-by-trait[d]
                    d3.select this .call y-axis


            cell = svg.select-all \.cell
                .data (cross traits, traits)
                .enter!.append \g
                .attr "class", "cell"
                .attr "transform", (d) -> "translate(" + (n - d.i - 1) * size + "," + d.j * size + ")"
                .each plot

            cell
                .filter (d) -> d.i == d.j
                .append \text
                .attr \x, padding
                .attr \y, padding
                .attr \dy, \.71em
                .text (.x)

            brush-cell = null

            brushstart = (p) ->
                if brush-cell !== this
                  d3.select brush-cell .call brush.clear!
                  x.domain domain-by-trait[p.x]
                  y.domain domain-by-trait[p.y]
                  brush-cell = this

            brushmove = (p) ->
                e = brush.extent!
                svg.select-all \circle .classed \hidden, (d) ->
                    e[0][0] > d[p.x] or d[p.x] > e[1][0]
                    or e[0][1] > d[p.y] or d[p.y] > e[1][1]

            brushend = ->
                if brush.empty!
                    svg.select-all \.hidden .classed \hidden, false

            brush = d3.svg.brush!
                .x x
                .y y
                .on \brushstart, brushstart
                .on \brush, brushmove
                .on \brushend, brushend

            cell.call brush





    # all functions defined here are accessibly by the presentation code
    presentaion-context = {        

        download

        download-and-plot

        Plottable

        project

        with-options

        plot

        more

        amore

        cell
        
        scell

        layout-horizontal: layout \horizontal

        layout-vertical: layout \vertical

        json

        csv

        pjson: new Plottable do
            (view, result, {pretty, space}, continuation) !-->
                pre = $ "<pre/>"
                    ..html if not pretty then JSON.stringify result else JSON.stringify result, null, space
                ($ view).append pre
            {pretty: true, space: 4}

        table: new Plottable (view, result, options, continuation) !--> 

            cols = result.0 |> Obj.keys |> filter (.index-of \$ != 0)
            
            #todo: don't do this if the table is already present
            $table = d3.select view .append \pre .append \table
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
        
            <- continuation $table, result


        histogram1: new Plottable do
            histogram.plotter
            histogram.options
            histogram.continuations
            (data, options) -> [{key: "", values: data}] |> ((fdata) -> histogram.projection fdata, options)


        histogram


        stacked-area: new Plottable do
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


        scatter1: new Plottable do
            scatter.plotter
            scatter.options
            scatter.continuations
            (data, options) -> data |> (map (d) -> {} <<< d <<< {
                key: (if !!options.key then options.key else (.key)) d
                values: [d]
            }) >> ((fdata) -> scatter.projection fdata, options)


        scatter

        correlation-matrix

        timeseries: new Plottable do
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

        multi-bar-horizontal: new Plottable do
            (view, result, {x, y, key, values, maps, stacked, y-axis, margin, show-values, tooltips, tooltip, transition-duration, show-controls}, continuation) !-->
                <- nv.add-graph

                result := result |> map (ds) ->
                    key: key ds
                    values: (values ds) |> map -> 
                        label: x it
                        value: (y it) |> maps[key ds]?.0 ? id

                chart = nv.models.multi-bar-horizontal-chart!
                    .x (.label)
                    .y (.value)
                    .margin margin
                    .show-values show-values
                    .tooltips tooltips
                    .tooltip tooltip
                    .transition-duration transition-duration
                    .show-controls show-controls
                    .stacked stacked
                
                chart
                    ..y-axis.tick-format y-axis.format

                <- continuation chart, result

                plot-chart view, result, chart

                chart.update!

            {
                x: (.label)
                y: (.value)
                stacked: true
                y-axis:
                    format: d3.format ',.2f'
                margin: top: 30, right: 20, bottom: 50, left: 175
                show-values: true
                tooltips: true
                tooltip: (key, x, y, e, graph) ->
                    '<h3>' + key + ' - ' + x + '</h3>' +
                    '<p>' +  y + '</p>'
                transition-duration: 350
                show-controls: true
                key: (.key)
                values: (.values)
                maps: {}
            }


        plot-line-bar: (view, result, {
            fill-intervals = true
            y1-axis-format = (d3.format ',f')
            y2-axis-format = (d3.format '.02f')

        }) !->
            <- nv.add-graph

            if options.fill-intervals
                result := result |> map ({key, values})-> {key, values: values |> fill-intervals}

            chart = nv.models.line-plus-bar-chart!
                .x (, i) -> i
                .y (.1)
            chart
                ..x-axis.tick-format (d) -> 
                    timestamp = data.0.values[d] and data.0.values[d].0 or 0
                    (d3.time.format \%x) new Date timestamp
                ..y1-axis.tick-format y1-axis-format
                ..y2-axis.tick-format y2-axis-format
                ..bars.force-y [0]

            plot-chart view, result, chart

            chart.update!


        # [[key, val]] -> [[key, val]]
        fill-intervals

        trendline: (v, sample-size)->
            [0 to v.length - sample-size]
                |> map (i)->
                    new-y = [i til i + sample-size] 
                        |> map -> v[it].1
                        |> average
                    [v[i + sample-size - 1].0, new-y]

    }    