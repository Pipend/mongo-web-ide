async = require \async 
config = require \./config 
express = require \express
fs = require \fs
md5 = require \MD5
moment = require \moment
vm = require \vm 
{compile} = require \LiveScript
{concat-map, dasherize, filter, find, keys, map, Str} = require \prelude-ls
{MongoClient, ObjectID, Server} = require \mongodb

app = express!
    ..set \views, __dirname + \/
    ..engine \.html, (require \ejs).__express
    ..set 'view engine', \ejs    
    ..use (require \cors)!
    ..use (require \cookie-parser)!
    ..use "/public" express.static "#__dirname/public"
    ..use (req, res, next)->
        return next! if req.method is not \POST
        body = ""
        req.on \data, -> body += it 
        req.on \end, -> 
            req <<< {body: JSON.parse body}
            next!

query-cache = {}

(err, db) <- MongoClient.connect config.mongo, config.mongo-options
return console.log err if !!err
console.log "successfully connected to #{config.mongo}"

compile-and-execute-livescript = (livescript-code, context)->

    die = (err)->
        [err, null]

    try 
        js = compile livescript-code, {bare: true}
    catch err
        return die "livescript transpilation error: #{err.to-string!}"

    try 
        result = vm.run-in-new-context js, context
    catch err
        return die "javascript runtime error: #{err.to-string!}"

    [null, result]

die = (res, err)->
    res.status 500
    res.end err

get-all-keys-recursively = (object, filter-function)->
    keys object |> concat-map (key)-> 
        return [] if !filter-function key, object[key]
        return [key] ++ (get-all-keys-recursively object[key], filter-function)  if typeof object[key] == \object
        [key]

get-default-document-state = -> 
    {query-name: "Unnamed query", query: "$limit: 5", transformation: "result", presentation: "json result"}

get-query-context = ->
    bucketize = (bucket-size, field) --> $divide: [$subtract: [field, $mod: [field, bucket-size]], bucket-size]
    parse-date = (s) -> new Date s
    to-timestamp = (s) -> (moment (new Date s)).unix! * 1000
    today = -> ((moment!start-of \day .format "YYYY-MM-DDT00:00:00.000") + \Z) |> parse-date
    {
        object-id: ObjectID
        bucketize
        timestamp-to-day: bucketize 86400000
        today: today!
        parse-date
        to-timestamp
    }

get-query-by-id = (query-id, callback) !->
    (err, results) <- db.collection \queries .aggregate do 
        [
            {
                $match: 
                    query-id: parse-int query-id
            }
            {
                $sort: _id: - 1
            }
        ]
    return callback err, null if !!err
    callback null, if !!results and results.length > 0 then results.0 else null

execute-query = (server-name, database, collection, query, parameters, callback) !->

    # parameters is String if coming from the single query interface; it is an empty object if coming from multi query interface
    if \String == typeof! parameters
        [err, parameters] = compile-and-execute-livescript parameters, get-query-context!
        return callback err, null if !!err

    # compile & execute livescript code to get the parameters for aggregation
    [err, query] = compile-and-execute-livescript query, get-query-context! <<< (require \prelude-ls) <<< parameters
    return callback err, null if !!err

    # retrieve the connection string from config
    connection-string = config.connection-strings |> find (.name == server-name)
    return callback (new Error "server name not found"), null if typeof connection-string == \undefined

    # connect to mongo server
    server = new Server connection-string.host, connection-string.port
    mongo-client = new MongoClient server, {native_parser: true}
    err, mongo-client <- mongo-client.open 
    return callback err, null if !!err

    # perform aggregation & close db connection
    err, result <- mongo-client.db database .collection collection .aggregate query
    mongo-client.close!
    return callback (new Error "mongodb error: #{err.to-string!}"), null if !!err

    callback null, result

# load a new document
app.get \/, (req, res)-> res.render \public/index.html, {remote-document-state: get-default-document-state! <<< config.default-connection-details} 

app.get \/aggregator, (req, res) ->
    res.render \public/aggregator.html, {}

# load an existing document
# returns JSON if request contains accept: application/json 
app.get "/:queryId(\\d+)", (req, res)->
    {query-id} = req.params
    err, remote-document-state <- get-query-by-id query-id
    if (req.headers.accept.index-of \application/json) > -1
        res.type \application/json
        res.send <| JSON.stringify remote-document-state
    else
        res.render \public/index.html, {remote-document-state: (remote-document-state or get-default-document-state!)} 

#
app.get "/delete/:queryId", (req, res)->
    (err, updated) <- db.collection \queries .update {query-id: parse-int req.params.query-id}, {$set: status: false}, {multi: 1}
    return die res, err if !!err    

    console.log \updated, updated

    res.end!

# extract keywords from the latest record (for auto-completion)
app.get \/keywords/queryContext, (req, res)->
    res.end JSON.stringify ((get-all-keys-recursively get-query-context!, -> true) |> map dasherize)

#
app.get \/keywords/:serverName/:database/:collection, (req, res)->
    (err, results) <- query-db.collection \events .aggregate do 
        [
            {
                $sort: _id: -1
            }
            {
                $limit: 1
            }
        ]
    return die err, res if !!err     
    collection-keywords = get-all-keys-recursively results.0, (k, v)-> typeof v != \function
    res.end JSON.stringify collection-keywords ++ (collection-keywords |> map -> "$#{it}")

# list all the queries
app.get \/list, (req, res)->
    (err, results) <- db.collection \queries .aggregate do
        [
            {
                $sort:
                    _id: 1
            }
            {
                $group:
                    _id: \$queryId
                    query-name: $last: \$queryName
                    status: $last: \$status
            }
        ]
    return die res, err if !!err
    res.render \public/list.html, {queries: results |> map ({_id, query-name, status})-> {query-id: _id, query-name, status}}

# transpile livescript, execute the mongo aggregate query and return the results
app.post \/query, (req, res)->

    {cache, server-name, database, collection, query, parameters = "{}"} = req.body    

    # return cached result if any
    key = md5 query    
    return res.end query-cache[key] if cache and !!query-cache[key]

    err, result <-  execute-query server-name, database, collection, query, parameters

    console.log err if !!err

    return die res, err.to-string! if !!err

    # cache and return the response
    res.end query-cache[key] = JSON.stringify result, null, 4


app.post \/multi-query, (req, res) ->

    convert-query-to-valid-livescript = (query)->

        lines = query.split \\n
            |> filter -> 
                line = it.trim!
                !(line.length == 0 || line.0 == \#)

        lines = [0 til lines.length] 
            |> map (i)-> 
                line = lines[i]
                line = (if i > 0 then "},{" else "") + line if line.0 == \$
                line

        "[{#{lines.join '\n'}}]"

    # compiles & executes livescript
    run-livescript = (context, livescript)-> 
        livescript = "\nglobal <<< require 'prelude-ls' \nglobal <<< context \n" + livescript
        try 
            return [null, eval compile livescript, {bare: true}]
        catch error 
            return [error, null]

    get-transformation-context = -> {}

    run-query = (query-id, parameters, callback) -->
        err, {query-name, server-name, database, collection, query, transformation} <- get-query-by-id query-id
        return callback err if !!err
        query := convert-query-to-valid-livescript query
        err, result <- execute-query server-name, database, collection, query, parameters
        return callback err if !!err
        [err, result] = run-livescript get-transformation-context!, "result = #{JSON.stringify result}\n#transformation"
        return callback err if !!err
        callback null, result

    {query} = req.body
    user-code = query

    code = """
(callback) ->
    fail = (err) !-> callback err, null
    done = (res) !-> callback null, res

#{user-code |> Str.lines |> map (-> "    " + it) |> Str.unlines}
    """

    [err, result] = run-livescript get-query-context!, code
    return die res, err.to-string! if !!err
    err, query-res <- result!
    return die res, err.to-string! if !!err

    # res.type \application/json
    res.end <| JSON.stringify query-res, null, 4
    
# save the code to mongodb
app.post \/save, (req, res)->

    (err, records) <- db.collection \queries .insert req.body <<< {creation-time: new Date!.get-time!, status: true}, {w: 1}
    return die res, err if !!err

    res.end JSON.stringify [null, records.0]

# query search based on name
app.get \/search, (req, res)->
    (err, results) <- db.collection \queries .aggregate do 
        [
            {
                $match: 
                    query-name: {$regex: ".*#{req.query.name}.*", $options: \i}
                    status: true
            }
            {
                $sort: _id: 1
            }
            {
                $group: 
                    _id: \$queryId
                    query-name: $last: \$queryName
            }            
        ]
    return die res, err if !!err
    res.end JSON.stringify (results |> map ({_id, query-name})-> {query-id: _id, query-name})

app.listen config.port
console.log "listening on port #{config.port}"




















