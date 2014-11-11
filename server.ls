async = require \async 
config = require \./config 
express = require \express
fs = require \fs
md5 = require \MD5
moment = require \moment
vm = require \vm 
{compile} = require \LiveScript
{concat-map, keys, map, filter} = require \prelude-ls
{MongoClient, ObjectID} = require \mongodb

app = express!
    ..set \views, __dirname + \/
    ..engine \.html, (require \ejs).__express
    ..set 'view engine', \ejs    
    ..use (require \cookie-parser)!
    ..use "/ace-builds" express.static "#__dirname/ace-builds"
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

(err, query-db) <- MongoClient.connect config.connection-strings.0, config.mongo-options
return console.log err if !!err
console.log "successfully connected to #{config.connection-strings.0}"


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

get-all-keys-recursively = (object)->
    keys object |> concat-map (key)-> 
        return [] if typeof object[key] == \function
        return [key, "$#{key}"] ++ (get-all-keys-recursively object[key])  if typeof object[key] == \object
        [key, "$#{key}"]

get-default-document-state = -> {name: "", query: "$limit: 5", transformation: "result", presentation: "json result"}

# load a new document
app.get \/, (req, res)-> res.render \public/index.html, get-default-document-state!

# load an existing document
app.get "/:queryId(\\d+)", (req, res)->

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
    res.render \public/index.html, remote-document-state
    
# extract keywords from the latest record (for auto-completion)
app.get \/keywords, (req, res)->
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
    res.end JSON.stringify (get-all-keys-recursively results.0) ++ config.test-ips

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
                    name: $last: \$name
            }
        ]
    return die res, err if !!err
    res.render \public/list.html, {queries: results |> map ({_id, name})-> {query-id: _id, name}}

# transpile livescript, execute the mongo aggregate query and return the results
app.post \/query, (req, res)->

    # return cached result if any
    key = md5 req.body.query    
    return res.end query-cache[key] if req.body.cache && !!query-cache[key]

    # context for livescript code
    bucketize = (bucket-size, field) --> $divide: [$subtract: [field, $mod: [field, bucket-size]], bucket-size]
    parse-date = (s) -> new Date s
    today = -> ((moment!start-of \day .format "YYYY-MM-DDT00:00:00.000") + \Z) |> parse-date
    query-context = {
        object-id: ObjectID
        bucketize
        timestamp-to-day: bucketize 86400000
        today: today!
        parse-date
    }

    # compile & execute livescript code to get the parameters for aggregation
    [err, query] = compile-and-execute-livescript req.body.query, query-context <<< require \prelude-ls
    return die res, err if !!err

    # perform aggregation
    (err, result) <- query-db.collection \events .aggregate query
    return die res, "mongodb error: #{err.to-string!}" if !!err

    # cache and return the response
    res.end query-cache[key] = JSON.stringify result, null, 4
    
# save the code to mongodb
app.post \/save, (req, res)->

    (err, records) <- db.collection \queries .insert req.body <<< {creation-time: new Date!.get-time!}, {w: 1}
    return die res, err if !!err

    res.end JSON.stringify [null, records.0]

app.listen config.port
console.log "listening on port #{config.port}"




















