React = require \react

create-element = (element, args)-> React.create-element.apply @, [element] ++ Array.prototype.slice.call args

module.exports = 
    $a: -> create-element \a, arguments
    $button: -> create-element \button, arguments    
    $circle: -> create-element \circle, arguments
    $div: -> create-element \div, arguments
    $g: -> create-element \g, arguments
    $h1: -> create-element \h1, arguments
    $input: -> create-element \input, arguments
    $li: -> create-element \li, arguments
    $line: -> create-element \line, arguments
    $path: -> create-element \path, arguments
    $svg: -> create-element \svg, arguments
    $ul: -> create-element \ul, arguments

 