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
{map} = require \prelude-ls
{get-presentation-context} = require \./presentation-context.ls

# module-global variables  
chart = null

# compiles & executes livescript
run-livescript = (context, result, livescript)-> 
    livescript = "window <<< require 'prelude-ls' \nwindow <<< context \n" + livescript           
    try
        javascript = compile livescript, {bare: true}
        return [null, eval javascript]
    catch error 
        return [error, null]
        
<- $
presentation = ($ \#presentation .html!)
presentation .= replace /\t/g, " "
[error] = run-livescript (get-presentation-context ($ \pre .get 0), ($ \svg .get 0), chart) <<< window.parameters, window.transformed-result, presentation
console.log error if !!error