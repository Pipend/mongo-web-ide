async = require \async 
config = require \./config 
express = require \express
fs = require \fs
md5 = require \MD5
moment = require \moment
vm = require \vm 
{compile} = require \LiveScript
{concat-map, dasherize, filter, find, keys, map} = require \prelude-ls
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
    today = -> ((moment!start-of \day .format "YYYY-MM-DDT00:00:00.000") + \Z) |> parse-date
    {
        object-id: ObjectID
        bucketize
        timestamp-to-day: bucketize 86400000
        today: today!
        parse-date
    }

# display a list of all queries
app.get \/, (req, res)-> res.render \public/query-list.html, {}

# set the status property of the query to false
app.get "/delete/:queryId", (req, res)->
    (err, updated) <- db.collection \queries .update {query-id: parse-int req.params.query-id}, {$set: status: false}, {multi: 1}
    return die res, err if !!err    

    console.log \updated, updated

    res.end!

# transpile livescript, execute the mongo aggregate query and return the results
app.post \/execute, (req, res)->

    {cache, server-name, database, collection, query} = req.body    

    # return cached result if any
    key = md5 query    
    return res.end query-cache[key] if cache && !!query-cache[key]

    # compile & execute livescript code to get the parameters for aggregation
    [err, query] = compile-and-execute-livescript req.body.query, get-query-context! <<< require \prelude-ls
    return die res, err if !!err

    # retrieve the connection string from config
    connection-string = config.connection-strings |> find (.name == server-name)
    return die res, "server name not found" if typeof connection-string == \undefined

    # connect to mongo server
    server = new Server connection-string.host, connection-string.port
    mongo-client = new MongoClient server, {native_parser: true}
    (err, mongo-client) <- mongo-client.open 
    return die res, err if !!err

    # perform aggregation & close db connection
    (err, result) <- mongo-client.db database .collection collection .aggregate query
    mongo-client.close!
    return die res, "mongodb error: #{err.to-string!}" if !!err

    # cache and return the response
    res.end query-cache[key] = JSON.stringify result, null, 4

# extract keywords from the latest record (for auto-completion)
app.get \/keywords/queryContext, (req, res)->
    res.end JSON.stringify ((get-all-keys-recursively get-query-context!, -> true) |> map dasherize)

# TODO: implement
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

# return a list of all queries
app.get \/list, (req, res)->
    search-string = req.query?.name or ""
    (err, results) <- db.collection \queries .aggregate do
        [
            {
                $match: 
                    query-name: {$regex: ".*#{search-string}.*", $options: \i}
            }
            {
                $sort:
                    _id: 1
            }
            {
                $group:
                    _id: \$queryId
                    creation-time: $first: \$creationTime
                    query-name: $last: \$queryName
                    status: $last: \$status
            }
        ]
    return die res, err if !!err
    json = results |> map ({_id, creation-time, query-name, status})-> {query-id: _id, creation-time, query-name, status}
    res.end JSON.stringify json
    
# load a new document
app.get \/query, (req, res)-> res.render \public/index.html, {remote-document-state: get-default-document-state! <<< config.default-connection-details} 

# load an existing document
app.get "/query/:queryId(\\d+)", (req, res)->

    {query-id} = req.params

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
    remote-document-state = get-default-document-state!
    remote-document-state = results.0 if err is null && !!results && results.length > 0
    res.render \public/ide.html, {remote-document-state: {} <<< remote-document-state} 

# save the code to mongodb
app.post \/save, (req, res)->

    (err, records) <- db.collection \queries .insert req.body <<< {creation-time: new Date!.get-time!, status: true}, {w: 1}
    return die res, err if !!err

    res.end JSON.stringify [null, records.0]

app.listen config.port
console.log "listening on port #{config.port}"




















