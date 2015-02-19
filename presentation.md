## Presentation

Presentation is a function that receives the view (a `DIVHTMLElement`) and a the result of transformation and its job is to present the result in the view.

A basic example:

```
(view, result) -->
  view.innerHTML = "<pre>#{(JSON.stringify result, null, 4)}</pre>"
```

There are many pre defined presentation functions, so you can just type `json` in the presentation in place of the above code.

Many presentation functions are instances of `Plottable` type. Here's how we use a plottable instance in the presentation block:

```
plot pjson
```

You can feed custom options to many plottables using `with-options` function.

Some plottables accept a continuation function that can be passed by `more` function.

Plottables can also be composed together using `layout` function.


#### **json**

_`(view, result) --> void`_

Prints JSON stringified string representation of its only argument.
Example:
```
json
```
#### **pjson**
_Plottable_

##### Example:
```
plot pjson `with-options` {space: 2}
```
 
#### **timeseries**
_Plottable_

##### Example:
```LiveScript
plot timeseries `with-options` {
    fill-intervals: false
    trend-line: null
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
```
##### Input Data:
```
[
    {
        "key": "Timeline A",
        "values": [
            [1423267200000, 105.3],
            [1423353600000, 107.6],
            ...
        ]
    },
    {
        "key": "Timeline B",
        "values": [
            [1423267200000, 151.5],
            [1423353600000, 142.9],
            ...
        ]
    }
]
```

##### Example:
```
plot timeseries `with-options` {
    x: (.0)
    y: (.1)
    fill-intervals: 0
    trend-line: (key) -> 
	    color: \green
	    sample-size: 10
	    name: "#key trend"
} `more` (chart) ->
    chart
        .force-y [0, 200]
        .update!
```

#### **timeseries1**
_Plottable_

##### Input Data:
```
[
    [1423267200000, 105.3],
    [1423353600000, 107.6],
    ...
]
```

#### **scatter**
_Plottable_

##### Example:
```
plot scatter
```
```
plot scatter `with-options` {
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

 }
```

##### Input Data:
```
[
    {
        key: 'Key A'
        values: [{x: 1, y: 1, size: 7}, {x: 2, y: 2.5, size: 10}, ...]
    },
    {
        key: 'Key B'
        values: [{x: 3, y: 4, size: 5}, {x: 2, y: 3.5, size: 6}, ...]
    },
    ...
]
```



####**scatter1**
_Plottable_

##### Input Data:
```
[
	{x: 1, y: 1}, {x: 2, y: 1.5}
]
```


####**stacked-area**
_Plottable_

##### Example:

```LiveScript
plot stacked-area `with-options` {
    x: (.0)
    y: (.1)
    key: (.key)
    values: (.values)
    x-axis: 
        tick-format: (timestamp)-> (d3.time.format \%x) new Date timestamp
    y-axis: 
        tick-format: d3.format ','
    show-legend: true
    show-controls: true
    clip-edge: true
    fill-intervals: 0
    use-interactive-guideline: true
}
```

##### Input Data:
```
[
    {
        "key": "Key A",
        "values": [
            [ 1422316800000, 8],
            [ 1422230400000, 14],
            ...
        ]
    },
    {
        "key": "Key B",
        "values": [
            [ 1422316800000, 34],
            [ 1422230400000, 53],
            ...
        ]
    },
    ...
]
```

####**histogram**
_Plottable_

##### Examples:
```
plot histogram `with-options` {
    key: (.key)
    values: (.values)
    x: (.0)
    y: (.1)
    transition-duration: 300
    reduce-x-ticks: false
    rotate-labels: 0 
    show-controls: true
    group-spacing: 0.1 
    show-legend: true
}
```
##### Input Data:
```
[ 
    {
        key: 'Group A', 
        values:  [["June 1", 100], ["June 2", 200], ...]
    },
    {
        key: 'Group B', 
        values:  [["June 1", 200], ["June 2", 300], ...]
    },
    ...
]
```


####**histogram1**
_Plottable_

##### Input Data:
```
[["June 1", 100], ["June 2", 200], ["June 3", 150], ...]
```

####**download**

_`(type, view, result) --> void`_

##### Example:

```
download \csv # (view, result) --> void
```

####**download-and-plot**

_`(type, Plottable, view, result) --> void`_

##### Example:
```
download-and-plot \json, pjson # (view, result) --> void
```

####**correlation-matrix**

_Plottable_

##### Example:
```
plot correlation-matrix `with-options` { 
	category: (.cat)
	traits: <[x y z a]> 
}
```
##### Input Data:
```
[
    {
        "x": 0.47,
        "y": 10.40,
        "z": 0.20,
        "a": -0.15,
        "cat": "a"
    },
    {
        "x": 1.53,
        "y": 6.23,
        "z": 0.13,
        "a": 2.57,
        "cat": "b"
    },
    ...
]
```

####**regression**

_Plottable_

Scatter chart with simple linear regression

##### Example:
```
plot regression `with-options` {
    x: (.x)
    y: (.y)
    size: (.size)
    y-axis:
        format: (d3.format '0.2f')
        label: 'Y'
    x-axis:
        format: (d3.format '0.2f')
        label: 'X'
    y-range: 
        min: (map (.y)) >> minimum
        max: (map (.y)) >> maximum
    tooltip: null
    margin: {top: 20, right:20, bottom: 50, left: 50}
}
```
##### Input Data:
```
[
    { "x": 2.34, "y": 0.03, "size": 3672 },
    { "x": 2.9, "y": 0.06, "size": 1483 },
    ...
]
```

####**multi-bar-horizontal**

_Plottable_

##### Example:
```
plot multi-bar-horizontal `with-options` {
    x: (.0)
    y: (.1)
    y-axis:
        format: d3.format ',.2f'
    margin: top: 30, right: 20, bottom: 50, left: 175
    show-values: true
    tooltips: true
    transition-duration: 350
    show-controls: true
    key: (.key)
    values: (.values)
    maps: 
        conversion: [(-> it * -10000)]
}
```
##### Input Data:
```
[
  {
    "key": "conversion",
    "values": [
        ["0", 0],
        ["3", 0.04],
        ["4", 0.03],
        ["5", 0.10],
        ["6", 0.07]
    ]
  },
  {
    "key": "visit",
    "values": [
        ["0", 1389],
        ["3", 48],
        ["4", 97],
        ["5", 523],
        ["6", 574]
    ]
  }
]
```