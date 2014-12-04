{filter, find, fold, map, sort-by} = require \prelude-ls
$ = require \jquery-browserify
React = require \react
{$a, $div, $input, $li, $ul} = require \./react-ls.ls
{search-queries-by-name} = require \./queries.ls

module.exports.query-search = React.create-class do

    render: ->
        queries = @?.state?.queries or []
        current-index = @?.state?.current-index or 0
        $div {class-name: \query-search},
            $div null,
                $div null,
                    $input {type: \text, on-input: @on-input, on-key-down: @on-key-down}
                    $ul null,
                        [0 til queries.length] |> map ->
                            $li {} <<< if current-index == it then {class-name: \highlight} else {},
                                $a {href: "http://localhost:3000/#{queries[it].query-id}"}, "#{queries[it].query-name} (#{queries[it].query-id})"

    component-did-mount: -> 
        @on-input!
        $ @get-DOM-node! .find \input .focus!

    on-input: (e)->        
        self = @
        (err, queries) <- search-queries-by-name (e?.current-target?.value or "")        
        return console.error err if !!err
        self.set-state {
            queries: queries |> sort-by (.match-index) 
            current-index: 0
        }

    on-key-down: (e)->
        key-code = e?.which or 0
        current-index = @?.state?.current-index or 0

        if key-code == 38 || key-code == 40
            current-index += if key-code == 38 then -1 else 1
            @set-state {current-index}
            ul = $ @get-DOM-node! .find \ul
            li = $ @get-DOM-node! .find "li:eq(#{current-index})"
            li-position = li.prev-all! |> fold ((memo, value)-> memo + ($ value .outer-height!)), 0
            ul.0.scroll-top = Math.max 0, (li-position + li.outer-height! - ul.height!)
            return false

        else if key-code == 13
            @.props.on-query-selected @?.state?.queries?[@?.state?.current-index]            
            return false

