$ = require \jquery-browserify

# nvd3 requires d3 to be in global space
window.d3 = require \d3-browserify
require \nvd3 

# the first require is used by browserify to import the LiveScript module
# the second require is defined in the LiveScript module and exports the object
require \LiveScript
{compile} = require \LiveScript

# the first require is used by browserify to import the prelude-ls module
# the second require is defined in the prelude-ls module and exports the object
require \prelude-ls
{keys, map, Str} = require \prelude-ls

{get-presentation-context} = require \./presentation-context.ls
{get-transformation-context} = require \./transformation-context.ls
{compile-and-execute-livescript} = require \./utils.ls

<- $
presentation = ($ \#presentation .html!).replace /\t/g, " "
[err, result] = compile-and-execute-livescript presentation, {result: transformed-result, view: document.body, d3, $} <<< get-transformation-context! <<< get-presentation-context! <<< parameters <<< (require \prelude-ls)
console.log err if !!err