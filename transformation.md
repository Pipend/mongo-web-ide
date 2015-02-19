## Transformation

### The need for transformation

### Transformation is a function
Transformation is a function with type: `x -> y` where `x` is the result of the query and `y` is the result of the transformation that will be piped to the presentation.

For example if the result of the query is a group of labels each containing an array of values and their frequencies:

```
[
  {
    label: "Group A",
    distribution: [
      {size: 10, value: 234},
      {size: 150, value: 124},
      ...
    ]
  },
  {
    label: "Group B",
    distribution: [
      {size: 100, value: 632},
      {size: 11, value: 25},
      ...
    ]
  }
  ...
]
```

You can calculate the expected value of each group by:

```
map ({label, distribution}) ->
  total = distribution |> sum . map (.size) 
  label: label
  expected-value: distribution |> 
    sum . map ({value, size}) -> value * size / total
```

The result of this transformation would be:

```

[
    {
        "label": "Group A",
        "expectedValue": 130.875
    },
    {
        "label": "Group B",
        "expectedValue": 571.8468468468468
    }
]
```