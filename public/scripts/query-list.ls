$ = require \jquery-browserify
React = require \react
{$a, $div, $input} = require \./react-ls.ls
require \prelude-ls
{find, map, sort-by, Str} = require \prelude-ls
{search-queries-by-name} = require \./queries.ls
moment = require \moment

query-list = React.create-class do

    render: ->
        
        $div {class-name: \query-list},

            # Menu
            $div {class-name: \menu},
                $a {class-name: \logo}
                $a {class-name: \button, href: \/query, target: \_blank}, \New
                $a {class-name: \link, href:\/logout}, \Logout
                
            # Search
            $div {class-name: \search, on-input: @on-search-string-change},
                $div {class-name: \grid},
                    $input {type:\search, placeholder: \Search...}
                    $div {class-name: \button}, \Search

            # Queries 
            $div {class-name: \queries},
                @.state.queries |> map ({query-id, query-name, creation-time, modification-time, storage})->
                    $div {class-name: \query},
                        $div {class-name: \avatar}
                        $a {class-name: \query-name, href: "/query/#{query-id}"}, query-name
                        $div {class-name: \storage}, (storage |> Str.join " & ")
                        $div {class-name: \tags}
                        $div {class-name: \right},                            
                            $div {class-name: \date}, moment(modification-time).format("ddd, DD MMM YYYY, hh:MM:ss A")
                            $div {class-name: 'control fork'}
                            
    on-search-string-change: (e)->
        self = @
        (err, queries) <- search-queries-by-name (e?.target?.value or "")
        self.set-state {queries: queries |> sort-by -> -it?.modification-time or 0}

    component-did-mount: -> @on-search-string-change!

    get-initial-state: ->
        {queries: []}

React.render (query-list {}), document.body