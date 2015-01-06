# the first require is used by browserify to import the prelude-ls module
# the second require is defined in the prelude-ls module and exports the object
require \prelude-ls
{Obj, average, concat-map, drop, each, filter, find, foldr1, id, map, maximum, minimum, obj-to-pairs, sort, sum, tail, take, unique} = require \prelude-ls

module.exports.get-presentation-context = ->

    layout = (view, direction, ...)!->            

            functions = drop 2, Array.prototype.slice.call arguments            

            child-views = [0  til functions.length]
                |> map (i)->
                    child-view = document.create-element \div
                        ..style <<< {                            
                            overflow: \auto
                            position: \absolute                            
                        }
                        ..class-name = direction
                    view.append-child child-view
                    [child-view, functions[i](child-view)]

            sizes = child-views 
                |> filter ([, size])-> !!size and typeof size == \number
                |> map ([, size])-> size                 

            default-size = (1 - (sum sizes)) / (child-views.length - sizes.length)

            child-views-with-size = child-views |> map ([child-view, size])-> [child-view, (size or default-size)]
                
            [0 til child-views-with-size.length]
                |> each (i)->
                    [child-view, size] = child-views-with-size[i]                    
                    position = take i, child-views-with-size
                        |> map ([, size])-> size
                        |> sum
                    child-view.style <<< {
                        left: if direction == \horizontal then "#{position * 100}%" else "0%"
                        top: if direction == \horizontal then "0%" else "#{position * 100}%"
                        width: if direction == \horizontal then "#{size * 100}%" else "100%"
                        height: if direction == \horizontal then "100%" else "#{size * 100}%"
                    }


    plot-chart = (view, result, chart)->
        d3.select view .append \div .attr \style, "position: absolute; left: 0px; top: 0px; width: 100%; height: 100%" .append \svg .datum result .call chart        

    # all functions defined here are accessibly by the presentation code
    {        

        layout-horizontal: (view, ...)!-> layout.apply @, [view, \horizontal] ++ tail Array.prototype.slice.call arguments

        layout-vertical: (view, ...)!-> layout.apply @, [view, \vertical] ++ tail Array.prototype.slice.call arguments

        json: (view, result)!--> 
            pre = $ "<pre/>"
                ..html JSON.stringify result, null, 4
            ($ view).append pre

        table: (view, result)!--> 

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
        

        plot-histogram: (view, result)!-->

            <- nv.add-graph

            chart = nv.models.multi-bar-chart!
                .x (.label)
                .y (.value)

            plot-chart view, result, chart
            
            chart.update!


        plot-stacked-area: (view, result, {y-axis-format = (d3.format ',')})!->

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
            
            chart.update!
            

        plot-scatter: (view, result, {tooltip, x-axis-format = (d3.format '.02f'), y-axis-format = (d3.format '.02f')})!->

            <- nv.add-graph

            chart = nv.models.scatter-chart!
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

            plot-chart view, result, chart
            
            chart.update!            

        plot-timeseries: (view, result)!->            

            <- nv.add-graph

            chart = nv.models.line-chart!
                .x (.0)
                .y (.1)
            chart.x-axis.tick-format (timestamp)-> (d3.time.format \%x) new Date timestamp
            
            plot-chart view, result, chart

            chart.update!


        fill-intervals: (v)->

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
                    [x-value, y-value or 0]
            

        trendline: (v, sample-size)->
            [0 to v.length - sample-size]
                |> map (i)->
                    new-y = [i til i + sample-size] 
                        |> map -> v[it].1
                        |> average
                    [v[i + sample-size - 1].0, new-y]

    }    






