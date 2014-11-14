{filter, find, fold, map, sort-by} = require \prelude-ls

window.query-search = React.create-class do

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
                                $a {href: "http://localhost:3000/#{queries[it].query-id}"}, "#{queries[it].name} (#{queries[it].query-id})"

    component-did-mount: -> 
        @on-input!
        $ @get-DOM-node! .find \input .focus!

    on-input: (e)->        
        self = @
        (queries) <- @search-queries (e?.current-target?.value or "")
        self.set-state {queries, current-index: 0}                        

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
            return cancel-event e

        else if key-code == 13
            @.props.on-query-selected @?.state?.queries?[@?.state?.current-index]            
            return cancel-event e

    search-queries: (name, callback)->
        @request.abort! if !!@request
        @request = $.get "/search?name=#{name}", (queries)-> 

            queries = JSON.parse queries

            local-queries = [0 to local-storage.length] 
                |> map -> local-storage.key it
                |> filter -> !!it
                |> map -> JSON.parse (local-storage.get-item it)
                |> filter -> (it.name.to-lower-case!.index-of name.to-lower-case!) != -1

            queries = queries
                |> filter ({query-id})->
                    local-query = local-queries |> find -> it.query-id == query-id
                    typeof local-query == \undefined

            all-queries = queries ++ local-queries
                |> map -> it <<< {match-index: it.name.to-lower-case!.index-of name.to-lower-case!}
                |> sort-by (.match-index)

            callback all-queries



