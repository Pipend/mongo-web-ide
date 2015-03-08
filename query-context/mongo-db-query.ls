config = require \./config
{id, concat-map, dasherize, difference, each, filter, find, find-index, foldr1, Obj, keys, map, obj-to-pairs, pairs-to-obj, Str, unique, any} = require \prelude-ls

# internal utility
objectify = (a) -> JSON.parse <| JSON.stringify a

poll = {}

# delegate
cancel = (db, client, query, start-time, callback) ->
    return if 'connected' != db.serverConfig?._serverState
    db.collection '$cmd.sys.inprog' .findOne (err, data) ->
        try
            return callback err, null

            queries = data.inprog #|> map (-> [it.opid, it.microsecs_running, it.query])

            # first try by matching query objects
            oquery = objectify query
            the-query = queries |> find (-> !!it.query?.pipeline and objectify it.query.pipeline === oquery)
        
            # second try by matching time
            if !the-query
                now = new Date!.value-of!
                #TODO...
            

            if !!the-query
                console.log "^^^ Canceling op #{the-query.opid}"

                err, data <- db.collection '$cmd.sys.killop' .findOne { 'op': the-query.opid }
                return callback err, null if !!err
                db.close!
                client.close!
                callback null, \killed
        catch error
            callback error, null

# utility function for executing a single mongpdb query
export execute-mongo-query = (query-id, type, server-name, database, collection, query, timeout, callback) !-->

    # retrieve the connection string from config
    connection-string = config.connection-strings |> find (.name == server-name)
    return callback (new Error "server name not found"), null if typeof connection-string == \undefined

    # connect to mongo server
    server = new Server connection-string.host, connection-string.port
    mongo-client = new MongoClient server, {native_parser: true}
    err, mongo-client <- mongo-client.open 
    return callback err, null if !!err

    # perform query & close db connection
    f = switch type
            | \aggregation => execute-mongo-aggregation-pipeline
            | \map-reduce => execute-mongo-map-reduce
            | _ => (..., callback) -> 
                callback (new Error "Unexpected query type '#type' \nExpected either 'aggregation' or 'map-reduce'."), null

    db = mongo-client.db database


    start-time = new Date!.value-of!

    kill = (kill-callback) ->
        cancel db, mongo-client, query, start-time, kill-callback
        delete poll[query-id]


    poll[query-id] = {kill}

    set-timeout do 
        kill (kill-error, kill-result) -> 
            return console.log \kill-error, kill-error if !!kill-error
            console.log \kill-result, kill-result
        timeout

    #(require \./ops).cancel-long-running-query 1200000, db, mongo-client, query

    err, result <- f (db.collection collection), query
    mongo-client.close!
    return callback (new Error "mongodb error: #{err.to-string!}"), null if !!err

    callback null, result

# query-id is generated at the client
export query = ({server-name, database, collection}:connection, query, parameters, query-id, callback) ->
    

    [err, transpiled-code] = compile-and-execute-livescript (convert-query-to-valid-livescript query), query-context
    return callback err, null if !!err
    
    if '$map' in (transpiled-code |> concat-map Obj.keys)
        [err, transpiled-code] = compile-and-execute-livescript ("{\n#{query}\n}"), query-context
        return callback err, null if !!err
        type = \map-reduce
    else
        type = \aggregation

    query-id = new Date!.value-of!!

    #TODO: get timeout from config
    execute-mongo-query type, server-name, database, collection, transpiled-code, 60000, query-id, callback

    
export cancel = (query-id, callback) ->
    query = poll[query-id]
    return callback (new Error "Query not found #{query-id}") if !query
    query.kill callback
