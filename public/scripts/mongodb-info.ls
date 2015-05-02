{DOM:{a, div, input, label, option, select, textarea}}:React = require \react
{camelize, each, find, map, sort, sort-by} = require \prelude-ls
$ = require \jquery-browserify

module.exports = React.create-class {

    render: ->

        {server-name, database, collection} = @.props
        
        servers = @.state.servers |> map ({name, display}) -> {label: display, value: name}
        databases = @.state.databases |> map -> {label: it, value: it}
        collections = @.state.collections |> map -> {label: it, value: it}

        [servers, databases, collections] = [[server-name, servers], [database, databases], [collection, collections]]
            |> map ([value, options]) ->
                (if typeof (options |> find (.value == value)) == \undefined then [{label: "- (#{value})", value}] else []) ++ (options |> sort-by (.label))

        div {class-name: \mongodb-info}, 
            [
                {
                    name: \server
                    value: server-name
                    options: servers
                    disabled: false
                    on-change: ({current-target:{value}}) ~> @.props.on-change {} <<< @.props <<< {server-name: value}
                }
                {
                    name: \database
                    value: database
                    options: databases
                    disabled: @.state.loading-databases
                    on-change: ({current-target:{value}}) ~> @.props.on-change {} <<< @.props <<< {database: value}
                }
                {
                    name: \collection
                    value: collection
                    options: collections
                    disabled: @.state.loading-collections
                    on-change: ({current-target:{value}}) ~> @.props.on-change {} <<< @.props <<< {collection: value}
                }
            ] |> map ({name, value, options, disabled, on-change}) ~>
                div {key: name},
                    label null, name
                    select {disabled, value, on-change},
                        options |> map -> option {key: it.value, value: it.value}, it.label

    get-initial-state: -> {servers: [], databases: [], collections: [], loading-databases: false, loading-collections: false}

    update-options: (prev-props, props) ->

        load-collections = (params) ~>
            @.set-state {loading-collections: true}
            @.collections-request.abort! if !!@.collections-request
            @.collections-request = $.post \/connections/mongodb, JSON.stringify params
                ..done ({collections}) ~>
                    @.set-state {collections, loading-collections: false}
                    @.props.on-change {} <<< @.props <<< {collection : collections.0} if !(props.collection in collections)

        if prev-props?.server-name != props?.server-name
            @.set-state {loading-databases: true, loading-collections: true}
            @.databases-request.abort! if !!@.databases-request
            @.databases-request = $.post \/connections/mongodb, JSON.stringify {connection: props.server-name}
                ..done ({databases}) ~>
                    @.set-state {databases, loading-databases: false}
                    database = 
                        | props.database in databases => props.database
                        | _ => databases.0
                    @.props.on-change {} <<< @.props <<< {database}
                    load-collections {connection: props.server-name, database}

        else if prev-props?.database != props?.database
            load-collections {connection: props.server-name, database: props.database}

    component-did-mount: ->
        ($.post \/connections/mongodb, '{}') .done ({connections}) ~> @.set-state {servers: connections}
        @.update-options {}, @.props

    component-will-receive-props: (props) -> @.update-options @.props, props


}
