# the first require is used by browserify to import the prelude-ls module
# the second require is defined in the prelude-ls module and exports the object
require \prelude-ls
{Obj, Str, id, any, average, concat-map, drop, each, filter, find, foldr1, foldl, map, maximum, minimum, obj-to-pairs, pairs-to-obj, sort, sum, tail, take, unique} = require \prelude-ls
d3-tip = require \d3-tip
d3-tip d3

{fill-intervals, rextend} = require \./presentation-plottables/_utils.ls


# Plottable is a monad, run it by plot funciton
class Plottable
    (@plotter, @options = {}, @continuations = ((..., callback) -> callback null), @projection = id) ->
    _plotter: (view, result) ~>
        @plotter view, (@projection result, @options), @options, @continuations

# Runs a Plottable
plot = (p, view, result) -->
    p._plotter view, result



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
    {} `rextend` p.options
    p.continuations
    (data, options) -> 
        fdata = f data, options
        p.projection fdata, options


download_ = (f, type, extension, result) -->
    blob = new Blob [f result], type: type
    a = document.create-element \a
    url = window.URL.create-objectURL blob
    a.href = url
    a.download = "file.#extension"
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


download-mime_ = (type, result) -->
    [f, mime, g] = match type
        | \json => [(-> JSON.stringify it, null, 4), \text/json, \json, json]
        | \csv => [json-to-csv, \text/csv, \csv, csv]
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

plottables = {

    download

    download-and-plot

    Plottable

    project

    with-options

    plot

    more

    amore

    json

    csv

} <<< {

    pjson: new Plottable do
        (view, result, {pretty, space}, continuation) !-->
            pre = $ "<pre/>"
                ..html if not pretty then JSON.stringify result else JSON.stringify result, null, space
            ($ view).append pre
        {pretty: true, space: 4}

    table: (require \./presentation-plottables/table.ls) {Plottable, d3, nv, plot-chart, plot}

    histogram1: (require \./presentation-plottables/histogram1.ls) {Plottable, d3, nv, plot-chart, plot}

    histogram: (require \./presentation-plottables/histogram.ls) {Plottable, d3, nv, plot-chart, plot}

    stacked-area: (require \./presentation-plottables/stacked-area.ls) {Plottable, nv, d3, plot-chart, plot}

    scatter1: (require \./presentation-plottables/scatter1.ls) {Plottable, d3, nv, plot-chart, plot}

    scatter: (require \./presentation-plottables/scatter.ls) {Plottable, d3, nv, plot-chart, plot}

    correlation-matrix: (require \./presentation-plottables/correlation-matrix.ls) {Plottable, d3, nv, plot-chart, plot}

    regression: (require \./presentation-plottables/regression.ls) {Plottable, d3, nv, plot-chart, plot}

    timeseries1: (require \./presentation-plottables/timeseries1.ls) {Plottable, d3, nv, plot-chart, plot}

    timeseries: (require \./presentation-plottables/timeseries.ls) {Plottable, d3, nv, plot-chart, plot}

    multi-bar-horizontal: (require \./presentation-plottables/multi-bar-horizontal.ls) {Plottable, d3, nv, plot-chart, plot}

} <<< (require \./presentation-plottables/layout.ls) {Plottable, d3, nv, plot-chart, plot}

module.exports.get-presentation-context = ->

    # all functions defined here are accessibly by the presentation code
    presentaion-context = {} <<< plottables <<< {        

        plot-line-bar: (view, result, {
            fill-intervals = true
            y1-axis-format = (d3.format ',f')
            y2-axis-format = (d3.format '.02f')

        }) !->
            <- nv.add-graph

            #if options.fill-intervals
            #    result := result |> map ({key, values})-> {key, values: values |> fill-intervals}

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

    }    