{DOM:{a, div, input, label, option, select, textarea}}:React = require \react
{map} = require \prelude-ls

module.exports = React.create-class {

    render: ->
        href = decode-URI-component "#{@.props.base-url}/rest/#{@.state.layer}/#{@.state.cache}/#{@.props.branch-id}#{if @.state.use-latest-query then '' else '/' + @.props.query-id}?#{@.props.query-string}"
        div {class-name: \link-generator},
            div null,
                label null, \layer
                select {
                    value: @.state.layer
                    on-change: ({current-target:{value}}) ~> @.set-state {layer: value}
                },
                    <[query transformation presentation]> |> map ->
                        option {value: it}, it
            div null,
                label {html-for: \use-latest-query}, 'use latest query'
                input {
                    id: \use-latest-query
                    type: \checkbox
                    checked: @.state.use-latest-query
                    on-change: ({current-target:{checked}}) ~> @.set-state {use-latest-query: checked} 
                }
            div null,
                label null, \cache
                select {
                    value: @.state.cache
                    on-change: ({current-target:{value}}) ~> @.set-state {cache: value}
                },
                    <[true false sliding]> |> map ->
                        option {value: it}, it
            a {href, target: "_blank"}, href

    get-initial-state: ->
        {layer: \presentation, use-latest-query: true, cache: false}
}
