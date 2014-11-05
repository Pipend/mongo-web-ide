config = require \./config
express = require \express
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

# load the IDE
app.get \/, (req, res)-> res.render \public/index.html

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


app.post \/transform, (req, res)->

    die = (err)->
        res.status 500
        res.end err

    {result, transformation} = JSON.parse req.body

    [err, transformed-data] = compile-and-execute-livescript transformation, {result: JSON.parse result} <<< require \prelude-ls
    return die err if !!err

    res.end JSON.stringify transformed-data, null, 4

app.listen config.port
console.log "listening on port #{config.port}"




















