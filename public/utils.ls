create-element = (element, args)-> React.create-element.apply @, [element] ++ Array.prototype.slice.call args

window <<< {

    $a: -> create-element \a, arguments
    $div: -> create-element \div, arguments
    $input: -> create-element \input, arguments
    $li: -> create-element \li, arguments
    $ul: -> create-element \ul, arguments

    cancel-event: ->
        it.prevent-default!
        it.stop-propagation!
        return false

}