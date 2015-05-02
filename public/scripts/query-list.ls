$ = require \jquery-browserify
{DOM:{a, div, input}}:React = require \react
require \prelude-ls
{find, map, sort-by, Str} = require \prelude-ls
{search-queries-by-name} = require \./queries.ls
moment = require \moment

query-list = React.create-class do

    render: ->
        
        div {class-name: \query-list},

            # Menu
            div {class-name: \menu},
                a {class-name: \logo}
                a {class-name: \button, href: \/branch, target: \_blank}, \New
                a {class-name: \link, href:\/logout}, \Logout
                
            # Search
            div {class-name: \search, on-input: @on-search-string-change},
                div {class-name: \grid},
                    input {type:\search, placeholder: \Search...}
                    div {class-name: \button}, \Search

            # Queries 
            div {class-name: \queries},
                @.state.queries |> map ({branch-id, query-id, query-name, creation-time, modification-time, storage, modified-by})->
                    div {class-name: \query},
                        div {class-name: \avatar, style: {background-image: "url('#{modified-by?.avatar}')"}}
                        div {class-name: \date}, moment(modification-time).format("ddd, DD MMM YYYY, hh:MM:ss A")
                        a {class-name: \query-name, href: "/branch/#{branch-id}/#{query-id}"}, query-name
                        div {class-name: \tags}
                        # div {class-name: \right},        
                            # div {class-name: 'control fork'}
                            
    on-search-string-change: (e)->
        self = @
        (err, queries) <- search-queries-by-name (e?.target?.value or "")
        self.set-state {queries: queries |> sort-by -> -it?.modification-time or 0}

    component-did-mount: -> @on-search-string-change!

    get-initial-state: ->
        {queries: []}

React.render (query-list {}), document.body