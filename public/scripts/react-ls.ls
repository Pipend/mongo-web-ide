# React = require \../lib/react/react.js

# create-element = (element, args)-> React.create-element.apply @, [element] ++ Array.prototype.slice.call args

# exports = {
#     $a: -> create-element \a, arguments
#     $div: -> create-element \div, arguments
#     $input: -> create-element \input, arguments
#     $li: -> create-element \li, arguments
#     $ul: -> create-element \ul, arguments
# }

module.exports = -> {x: 1, y: 1}