async = require \async
config = require \./config
express = require \express
fs = require \fs
vm = require \vm
{concat-map, keys, map} = require \prelude-ls
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

die = (res, err)->
    res.status 500
    res.end err

get-all-keys-recursively = (object)->
    keys object |> concat-map (key)-> 
        return [] if typeof object[key] == \function
        return [key, "$#{key}"] ++ (get-all-keys-recursively object[key])  if typeof object[key] == \object
        [key, "$#{key}"]

# load a new document
app.get \/, (req, res)-> res.render \public/index.html, {query-id: null, name: "", query: "", transformation-code: \result, presentation-code: "json result"}

# load an existing document
app.get "/:queryId(\\d+)", (req, res)->

    {query-id} = req.params

    (err, data) <- fs.read-file "./tmp/#{query-id}.json", \utf8
    return die res, err if !!err
    res.render \public/index.html, {name: ""} <<< (JSON.parse data) <<< {query-id: parse-int query-id}

# extract keywords from the latest record (for auto-completion)
app.get \/keywords, (req, res)->
    (err, results) <- db.collection \events .aggregate do 
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

# list all the queries
app.get \/list, (req, res)->

    # get the files from tmp directory
    (err, files) <- fs.readdir \./tmp
    return die res, err if !!err

    # read each file 
    (err, result) <- async.map do 
        files
        (file, callback)->

            (err, data) <- fs.read-file "./tmp/#{file}", \utf8            
            return callback err, null if !!err 

            callback null, JSON.parse data

    res.render \public/list.html, {queries: result |> map ({query-id, name})-> {query-id, description: "#{name} (#{query-id})"}}

# transpile livescript, execute the mongo aggregate query and return the results
app.post \/query, (req, res)->
    
    [err, query] = compile-and-execute-livescript req.body, {
        object-id: ObjectID
        timestamp-to-day: (timestamp-key)-> $divide: [$subtract: [timestamp-key, $mod: [timestamp-key, 86400000]], 86400000]
    } <<< require \prelude-ls
    return die res, err if !!err

    (err, result) <- db.collection \events .aggregate query
    return die res, "mongodb error: #{err.to-string!}" if !!err
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




















