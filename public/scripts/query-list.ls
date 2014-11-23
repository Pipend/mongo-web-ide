$ = require \../lib/jquery/dist/jquery.js
React = require \../lib/react/react.js
{$a, $div, $input} = require \./react-ls.ls
require \../lib/prelude-browser-min/index.js
{each, map, find, filter, is-it-NaN, sort-by, unique-by} = require \prelude-ls
{search-queries-by-name} = require \./queries.ls
moment = require \../lib/moment/moment.js

query-list = React.create-class do
    
    render: ->
        $div {class-name: \query-list},

            # Search
            $div {class-name: \search, on-input: @on-search-string-change},
                $div {class-name: \grid},
                    $input {type:\search, placeholder: \Search...}
                    $div {class-name: \button}, \Search

            # Queries
            $div {class-name: \queries},
                @.state.queries |> map ->
                    $div {class-name: \query},
                        $div {class-name: \avatar}
                        $a {class-name: \query-name, href: "/query/#{it.query-id}"}, it.query-name
                        $div {class-name: \tags}
                        $div {class-name: \right},
                            $div {class-name: \creation-date}, moment(it?.creation-time).format("ddd, DD MMM YYYY, hh:MM:ss A")
                            $div {class-name: 'control fork'}
                    
    on-search-string-change: (e)->
        self = @
        (err, queries) <- search-queries-by-name (e?.target?.value or "")
        self.set-state {queries}

    component-did-mount: -> @on-search-string-change!

    get-initial-state: ->
        {queries: []}

React.render (query-list {}), document.body