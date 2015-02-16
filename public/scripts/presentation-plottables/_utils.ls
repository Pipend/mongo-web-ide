{map, foldr1, maximum, minimum, find} = require \prelude-ls

export fill-intervals = (v, default-value = 0) ->

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