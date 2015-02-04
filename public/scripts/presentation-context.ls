# the first require is used by browserify to import the prelude-ls module
# the second require is defined in the prelude-ls module and exports the object
require \prelude-ls
{Obj, average, concat-map, drop, each, filter, find, foldr1, id, map, maximum, minimum, obj-to-pairs, sort, sum, tail, take, unique} = require \prelude-ls

class Plottable
    (@_plotter, @options = {}, @continuations = (chart, callback) -> callback null, chart) ->
    plotter: ({result, view}) ~>
        @_plotter {result, view}, @options, @continuations

plot = (p, {result, view}) -->
  p.plotter {result, view}


plottablify = (f) ->
    new Plottable ({result, view}, options, continuation) !-->
        f {result, view}

with-options = (p, o) ->
  new Plottable do
    p._plotter
    {} <<< p.options <<< o
    p.continuations
 
 
acompose = (f, g) --> (chart, callback) ->
  err, fchart <- f chart
  return callback err, null if !!err
  g fchart, callback
 
 
amore = (p, c) ->
  new Plottable do
    p._plotter
    {} <<< p.options
    p.continuations `acompose` c
 
 
more = (p, c) ->
  new Plottable do
    p._plotter
    {} <<< p.options
    p.continuations `acompose` (chart, callback) -> 
      try 
        cchart = c chart
      catch ex
        return callback ex, null
      callback null, cchart
 

project = (f, p) -->
  new Plottable do
    ({result, view}, options, continuation) !-->  # duck
      p.plotter {view, result: (f result)}


cell = (plotter) ->
  {plotter}


scell = (size, plotter) ->
  {size, plotter}

# async id
aid = (chart, callback) -> callback null, chart


module.exports.get-presentation-context = ->

    layout = (direction, cells) --> 
        if "Array" != typeof! cells
            cells := drop 1, [].slice.call arguments

        new Plottable ({result, view}, options, continuation) !-->
            child-view-sizes = cells |> map ({size, plotter}) ->
                    child-view = document.create-element \div
                        ..style <<< {                            
                            overflow: \auto
                            position: \absolute                            
                        }
                        ..class-name = direction
                    view.append-child child-view
                    plot plotter, {view: child-view, result}
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

    json = ({view, result}) !-> 
        pre = $ "<pre/>"
            ..html JSON.stringify result, null, 4
        ($ view).append pre

    plot-chart = (view, result, chart)->
        d3.select view .append \div .attr \style, "position: absolute; left: 0px; top: 0px; width: 100%; height: 100%" .append \svg .datum result .call chart        

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
        



    # all functions defined here are accessibly by the presentation code
    presentaion-context = {        

        plottablify

        project

        cell
        
        scell

        layout-horizontal: layout \horizontal #(view, ...)!-> layout.apply @, [view, \horizontal] ++ tail Array.prototype.slice.call arguments

        layout-vertical: layout \vertical #(view, ...)!-> layout.apply @, [view, \vertical] ++ tail Array.prototype.slice.call arguments

        json

        pjson: new Plottable do
            ({view, result}, {pretty, space}, continuation) !-->
                pre = $ "<pre/>"
                    ..html if not pretty then JSON.stringify result else JSON.stringify result, null, space
                ($ view).append pre
            {pretty: true, space: 4}

        table: new Plottable ({view, result}, options, continuation) !--> 

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
        
            err, $table <- continuation {$table: $table, result}

        plot-histogram: (view, result)!-->

            <- nv.add-graph

            chart = nv.models.multi-bar-chart!
                .x (.label)
                .y (.value)

            plot-chart view, result, chart
            
            chart.update!


        plot-stacked-area: new Plottable do
            ({result, view}, options, continuation) !-->

                <- nv.add-graph 

                all-values = result |> concat-map (.values |> concat-map (.0)) |> unique |> sort
                result := result |> map ({key, values}) ->
                    key: key
                    values: all-values |> map ((v) -> [v, values |> find (.0 == v) |> (?.1 or 0)])

                chart = nv.models.stacked-area-chart!
                    .x (.0)
                    .y (.1)
                    .useInteractiveGuideline true
                    .show-controls true
                    .clip-edge true

                chart
                    ..x-axis.tick-format (timestamp)-> (d3.time.format \%x) new Date timestamp
                    ..y-axis.tick-format y-axis-format
                
                plot-chart view, result, chart

                err, chart <- continuation {chart, result}
                throw err if !!err
                
                chart.update!

            {y-axis-format: (d3.format ',')}
                

        plot-scatter: (view, result, uoptions, callback = $.noop)!->

            options = {tooltip: null, x-axis-format: (d3.format '.02f'), y-axis-format: (d3.format '.02f'), show-legend: true} <<< uoptions
            console.log options
            <- nv.add-graph

            chart = nv.models.scatter-chart!
                .show-dist-x true
                .show-dist-y true
                .transition-duration 350
                .color d3.scale.category10!.range!

            chart
                ..scatter.only-circles false

                ..tooltip-content (key, , , {point}) -> 
                    (options.tooltip or (key) -> '<h3>' + key + '</h3>') key, point

                ..x-axis.tick-format options.x-axis-format
                ..y-axis.tick-format options.y-axis-format

            chart.show-legend !!options.show-legend
            plot-chart view, result, chart
            
            
            chart.update!

            callback chart            


        with-options

        plot

        more

        amore

        timeseries: new Plottable do
            ({result, view}, options, continuation) !-->

                <- nv.add-graph

                if options.fill-intervals
                    result := result |> map ({key, values})-> {key, values: values |> fill-intervals}

                chart = nv.models.line-chart!
                    .x (.0)
                    .y (.1)
                chart
                    ..x-axis.tick-format (timestamp)-> (d3.time.format \%x) new Date timestamp
                
                plot-chart view, result, chart

                err, chart <- continuation {chart, result}
                throw err if !!err

                chart.update!

            {fill-intervals: false, x-label: 'X', x: (.x), y: (.y)}


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