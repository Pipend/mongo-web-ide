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
{map, Str} = require \prelude-ls
{get-presentation-context} = require \./presentation-context.ls
{get-transformation-context} = require \./transformation-context.ls

# module-global variables  
chart = null

<- $
presentation = ($ \#presentation .html!).replace /\t/g, " "

try
	eval compile do 
		"""
		window <<< (require 'prelude-ls') <<< get-presentation-context! <<< get-transformation-context! <<< window.parameters
		#{presentation}
		"""
		{bare: true}	
	draw document.body, window.transformed-result

catch err
	console.log err.to-string!




