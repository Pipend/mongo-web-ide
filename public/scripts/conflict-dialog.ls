{filter, find, fold, map, sort-by} = require \prelude-ls
React = require \react
{$button, $circle, $div, $line, $path, $svg} = require \./react-ls.ls

module.exports.conflict-dialog = React.create-class do 

    render: ->

        {width, height, queries} = @.props
        {radius, horizontal-distance, resolution} = @.state

        nodes = [0 til queries.length] 
            |> map (i)-> {x: (i * horizontal-distance), y: radius}

        links = [0 til nodes.length - 1]
            |> map (i)-> {source: nodes[i], target: nodes[i + 1]}

        circles = nodes |> map ({x, y})-> $circle {r: radius, transform: "translate(#x, #y)"}

        {x, y} = nodes[nodes.length - 1]

        extra-circles = [
            {r: radius, transform: "translate(#{x + horizontal-distance} #y)", class-name: (if resolution == \new-commit then \highlight else \dim)}
            {r: radius, transform: "translate(#{horizontal-distance} #horizontal-distance)", class-name: (if resolution == \fork then \highlight else \dim)}
        ] |> map -> $circle it

        lines = links
            |> filter ({source, target})-> !!source and !!target
            |> map ({source, target})-> $line {x1: source.x, y1: source.y, x2: target.x, y2: target.y}

        extra-lines = [
            {x1: x, y1: y, x2: (x + horizontal-distance), y2: y, class-name: (if resolution == \new-commit then \highlight else \dim)}
            {x1: 0, y1: y, x2: horizontal-distance, y2: horizontal-distance, class-name: (if resolution == \fork then \highlight else \dim)}
        ] |> map -> $line it

        $div {class-name: \conflict-dialog}, 
            $svg {style: {width, height}}, (lines ++ extra-lines ++ circles ++ extra-circles)
            $div null,
                $button {click: @.on-reset-click}, "Reset"
                $button {on-mouse-over: @.on-fork-mouseover, on-mouse-out: @.on-mouseout}, "Fork Query"
                $button {on-mouse-over: @.on-new-query-mouseover, on-mouse-out: @.on-mouseout}, "New Query"

    component-did-mount: ->


    get-initial-state: ->       
        {radius: 10, horizontal-distance: @.props.width / (@.props.queries.length + 1), resolution: \none}

    on-fork-mouseover: ->
        @.set-state {resolution: \fork}

    on-mouseout: ->
        @.set-state {resolution: \none}

    on-new-query-mouseover: ->
        @.set-state {resolution: \new-commit}

    on-reset-click: ->
        console.log \reset