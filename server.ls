config = require \./config
express = require \express
vm = require \vm
{MongoClient, ObjectID} = require \mongodb
{compile} = require \LiveScript

app = express!
    ..set \views, __dirname + \/
    ..set 'view engine', \jade
    ..use (require \cookie-parser)!
    ..use "/ace-builds" express.static "#__dirname/ace-builds"
    ..use "/public" express.static "#__dirname/public"

(err, db) <- MongoClient.connect config.mongo, config.mongoOptions

return console.log err if !!err
console.log "successfully connected to #{config.mongo}"

# define a context object for executing livescript code
mongo-context = {ObjectID} <<< require \prelude-ls

# load the IDE
app.get \/, (req, res)-> res.render \public/index.jade

# transpile livescript, execute the mongo aggregate query and return the results
app.post \/query, (req, res)->
    
    body = ""
    req.on \data, -> body += it 
    req.on \end, ->

        try 
            js = compile body, {bare: true}
        catch err
            return res.end "livescript transpilation error: #{err.to-string!}"

        try 
            query = vm.run-in-new-context js, mongo-context
        catch err
            return res.end "javascript runtime error: #{err.to-string!}"

        (err, result) <- db.collection \events .aggregate query
        return res.end "mongodb error: #{err.to-string!}" if !!err
        res.end JSON.stringify result, null, 4


app.listen config.port
console.log "listening on port #{config.port}"