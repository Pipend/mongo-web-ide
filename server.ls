config = require \./config
express = require \express
fs = require \fs
vm = require \vm
{MongoClient, ObjectID} = require \mongodb
{compile} = require \LiveScript

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
            req <<< {body}
            next!

(err, db) <- MongoClient.connect config.mongo, config.mongoOptions

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

# load a new document
app.get \/, (req, res)-> res.render \public/index.html, {query-id: null, query: "", transformation-code: \@result, presentation-code: \@json!}

# load an existing document
app.get "/:queryId(\\d+)", (req, res)->

    die = (err)->
        res.status 500
        res.end err.to-string!

    {query-id} = req.params

    (err, data) <- fs.read-file "./tmp/#{query-id}.json", \utf8
    return die err if !!err
    res.render \public/index.html, (JSON.parse data) <<< {query-id: parse-int query-id}

# transpile livescript, execute the mongo aggregate query and return the results
app.post \/query, (req, res)->
    
    die = (err)->
        res.status 500
        res.end err

    [err, query] = compile-and-execute-livescript req.body, {
        object-id: ObjectID
        timestamp-to-day: (timestamp-key)-> $divide: [$subtract: [timestamp-key, $mod: [timestamp-key, 86400000]], 86400000]
    } <<< require \prelude-ls
    return die err if !!err

    (err, result) <- db.collection \events .aggregate query
    return die "mongodb error: #{err.to-string!}" if !!err
    res.end JSON.stringify result, null, 4

# save code to tmp directory
app.post \/save, (req, res)->

    # generate a query-id (if not present in the request)
    {query-id} = JSON.parse req.body
    query-id = new Date!.get-time! if !query-id

    # save the document as json & return the query-id
    (err) <- fs.write-file "./tmp/#{query-id}.json", req.body
    if !!err
        res.status 500
        res.end JSON.stringify [err, null]
        return
    res.end JSON.stringify [null, query-id]

app.listen config.port
console.log "listening on port #{config.port}"




















