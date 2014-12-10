{plot-commit-tree} = require \./queries.ls
$ = require \jquery-browserify
d3 = require \d3-browserify

<- $

plot-commit-tree window.queries, (d3.select \body), window.inner-width, window.inner-height
