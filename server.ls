async = require \async
base62 = require \base62
config = require \./config
express = require \express
session = require \express-session
fs = require \fs
md5 = require \MD5
moment = require \moment
{compile} = require \LiveScript
{MongoClient, ObjectID, Server} = require \mongodb
passport = require \passport
github-strategy = (require \passport-github).Strategy
{concat-map, dasherize, difference, each, filter, find, find-index, keys, map, Str, unique} = require \prelude-ls
{get-transformation-context} = require \./public/scripts/transformation-context
request = require \request
vm = require \vm

# global variables
query-cache = {}

# utility functions
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

# filters out empty lines and lines that begin with comment
# also encloses the query objects in a collection
convert-query-to-valid-livescript = (query)->

    lines = query.split (new RegExp "\\r|\\n")
        |> filter -> 
            line = it.trim!
            !(line.length == 0 || line.0 == \#)

    lines = [0 til lines.length] 
        |> map (i)-> 
            line = lines[i]
            line = (if i > 0 then "},{" else "") + line if line.0 == \$
            line

    "[{#{lines.join '\n'}}]"

die = (res, err)->
    res.status 500
    res.end err.to-string!

execute-mongo-aggregation-pipeline = (server-name, database, collection, query, callback) !-->

    # retrieve the connection string from config
    connection-string = config.connection-strings |> find (.name == server-name)
    return callback (new Error "server name not found"), null if typeof connection-string == \undefined

    # connect to mongo server
    server = new Server connection-string.host, connection-string.port
    mongo-client = new MongoClient server, {native_parser: true}
    err, mongo-client <- mongo-client.open 
    return callback err, null if !!err

    # perform aggregation & close db connection
    err, result <- mongo-client.db database .collection collection .aggregate query, {allow-disk-use: config.allow-disk-use}
    mongo-client.close!
    return callback (new Error "mongodb error: #{err.to-string!}"), null if !!err

    callback null, result

execute-query = (query-database, {server-name, database, collection, multi-query, query, cache, parameters}:document, callback) !-->

    # parameters is String if coming from the single query interface; it is an empty object if coming from multi query interface
    if \String == typeof! parameters
        [err, parameters] = compile-and-execute-livescript parameters, get-query-context!
        return callback err, null if !!err

    # return cached result if any
    key = md5 (query + "\n" + JSON.stringify parameters)    
    return callback null, query-cache[key] if cache and !!query-cache[key]    

    # context properties that are same for different query types
    query-context = get-query-context! <<< (require \prelude-ls) <<< parameters

    if multi-query

        code = """
(callback) ->
    fail = (err) !-> callback err, null
    done = (res) !-> callback null, res

#{query |> Str.lines |> map (-> "    " + it) |> Str.unlines}
        """

        [err, transpiled-code] = compile-and-execute-livescript do
            code
            query-context <<< {

                run-query: (query-id, parameters, callback)-> 

                    err, document <- get-query-by-id query-id
                    return callback err, null if !!err

                    execute-and-transform-query query-database, (document <<< {parameters}), callback

                run-latest-query: (branch-id, parameters, callback)->

                    err, document <- get-latest-query-in-branch query-database, branch-id
                    return callback err, null if !!err

                    execute-and-transform-query query-database, (document <<< {parameters}), callback

                run-queryb: (branch-id, parameters, callback)->

                    err, document <- get-latest-query-in-branch query-database, branch-id
                    return callback err, null if !!err

                    execute-and-transform-query query-database, (document <<< {parameters}), callback

            }
        return callback err, null if !!err   

        err, result <- transpiled-code!
        return callback err, null if !!err

        callback null, query-cache[key] = result          

    else

        [err, transpiled-code] = compile-and-execute-livescript (convert-query-to-valid-livescript query), query-context
        return callback err, null if !!err

        err, result <- execute-mongo-aggregation-pipeline server-name, database, collection, transpiled-code
        return callback err, null if !!err

        callback null, query-cache[key] = result
    
execute-and-transform-query = (query-database, {parameters, transformation}:document, callback) !-->

    err, result <- execute-query query-database, document
    return callback err, null if !!err

    # apply transformation
    [err, transformed-result] = compile-and-execute-livescript transformation, (get-transformation-context! <<< (require \prelude-ls) <<< {result} <<< parameters)
    callback err, transformed-result

get-all-keys-recursively = (object, filter-function)->
    keys object |> concat-map (key)-> 
        return [] if !filter-function key, object[key]
        return [key] ++ (get-all-keys-recursively object[key], filter-function)  if typeof object[key] == \object
        [key]

get-default-document-state = -> 
    {query-name: "Unnamed query", query: "$limit: 5", transformation: "result", presentation: "json view, result"} <<< config.default-connection-details

get-latest-query-in-branch = (query-database, branch-id, callback) !-->

    err, results <- query-database.collection \queries .aggregate do 
        [
            {
                $match: {
                    branch-id
                    status: true
                }
            }
            {
                $sort: _id: -1
            }
        ]
    return callback err, null if !!err
    return callback "unable to find any query in branch: #{branch-id}", null if typeof results == \undefined || typeof results?.0 == \undefined
    callback null, results.0

get-query-context = ->
    bucketize = (bucket-size, field) --> $divide: [$subtract: [field, $mod: [field, bucket-size]], bucket-size]
    parse-date = (s) -> new Date s
    to-timestamp = (s) -> (moment (new Date s)).unix! * 1000
    today = -> ((moment!start-of \day .format "YYYY-MM-DDT00:00:00.000") + \Z) |> parse-date
    {

        # dependent on mongo operations
        bucketize: bucketize
        day-to-timestamp: (field) -> $multiply: [field, 86400000]
        object-id: ObjectID
        timestamp-to-day: bucketize 86400000

        # independent of any mongo operations
        parse-date
        to-timestamp
        today: today!

    }

get-query-by-id = (query-database, query-id, callback) !-->
    (err, results) <- query-database.collection \queries .aggregate do 
        [
            {
                $match: {query-id}
            }
            {
                $sort: _id: - 1
            }
        ]
    return callback err, null if !!err
    callback null, if !!results and results.length > 0 then results.0 else null

# connect to mongo-db
(err, query-database) <- MongoClient.connect config.mongo, config.mongo-options
return console.log err if !!err
console.log "successfully connected to #{config.mongo}"

# create & setup express app
app = express!
    ..set \views, __dirname + \/
    ..engine \.html, (require \ejs).__express
    ..set 'view engine', \ejs    
    ..use (require \serve-favicon) __dirname + '/public/images/favicon.png'
    ..use (require \cors)!
    ..use (require \cookie-parser)!
    ..use (req, res, next)->
        return next! if req.method is not \POST
        body = ""
        req.on \data, -> body += it 
        req.on \end, -> 
            req <<< {body: JSON.parse body}
            next!
    ..use (require \method-override)!
    ..use (session {secret: 'keyword cat'})
    ..use passport.initialize!
    ..use passport.session!
    ..use (req, res, next)->

        # get the user object from query string & store it in the session
        user-id = req?.query?.user-id or (if config.authentication.strategy.name == \none then 1 else null)
        req._passport.session.user = {id: user-id, username: \guest} if !!user-id

        # get the user object from the session & store it in the request
        # the req.is-authenticated() method checkes the request object
        if !!req._passport.session.user
            property = req?._passport?.instance?._userProperty or \user
            req[property] = req._passport.session.user

        next!

    ..use "/public" express.static "#__dirname/public"
    ..use "/node_modules" express.static "#__dirname/node_modules"

# github passport strategy
if config.authentication.strategy.name == \github
    passport.use new github-strategy do 
        {
            clientID: config.authentication.strategy.options.client-id
            client-secret: config.authentication.strategy.options.client-secret
        }
        (accessToken, refreshToken, profile, done) ->

            die = (err)->
                console.log "github authentication error: #{err}"
                return done err, null 

            organizations-url = profile?._json?.organizations_url
            return die "organizations url not found" if !organizations-url

            (error, response, body) <- request do 
                headers:
                    'User-Agent': "Mongo Web IDE"
                url: organizations-url
            return die error if !!err

            organization-member = (JSON.parse body) |> find (.login == config.authentication.strategy.options.organization-name)
            return die "not part of #{config.organization-name}" if !organization-member

            done null, profile    

    # redirect user to github
    app.get \/auth/github, passport.authenticate \github, {scope: <[user]>}

    # user is redirected to this route by github
    app.get \/auth/github/callback,  passport.authenticate(\github, { failure-redirect: '/login' }), (req, res)-> res.redirect \/

# convert github data to user-id
passport.serialize-user (user, done)-> done null, user

# convert user-id to github data
passport.deserialize-user (obj, done)-> done null, obj

# login with github page
app.get \/login, (req, res)-> 
    return (res.redirect \/) if req.is-authenticated!
    res.render \public/login.html

# invokes req.logout!
app.get \/logout, (req, res)-> 
    req.logout!
    res.redirect \/

# ROUTES FROM THIS POINT ON REQUIRE AUTHENTICATION
app.use (req, res, next)->
    return next! if req.is-authenticated!
    res.redirect \/login

# display a list of all queries
app.get \/, (req, res)-> res.render \public/query-list.html, {req.user}

# load a new document
<[/branch /branch/local/:localQueryId /branch/local-fork/:localQueryId]>
    |> each ->
        app.get it, (req, res)->
            res.render \public/ide.html, {remote-document-state: get-default-document-state!} 

# redirect to latest query in the branch
app.get "/branch/:branchId([a-zA-Z0-9]+)", (req, res)->

    err, {query-id} <- get-latest-query-in-branch query-database, req.params.branch-id
    return die res, err if !!err

    res.redirect "/branch/#{req.params.branchId}/#{query-id}"

# load an existing document
app.get "/branch/:branchId([a-zA-Z0-9]+)/:queryId([a-zA-Z0-9]+)", (req, res)->

    {query-id} = req.params

    err, {status}:remote-document-state <- get-query-by-id query-database, query-id
    return die res, err if !!err
    return die res, "query deleted" if !status

    if (req.headers.accept.index-of \application/json) > -1
        res.type \application/json
        res.send <| JSON.stringify remote-document-state

    else
        res.render \public/ide.html, {remote-document-state: (remote-document-state or get-default-document-state!)}

# set the status property of the query to false
app.get "/delete/query/:queryId", (req, res)->

    (err, results) <- query-database.collection \queries .aggregate do 
        [
            {
                $match:
                    query-id: req.params.query-id
            }
        ]
    return die res, err if !!err
    
    (err) <- query-database.collection \queries .update {query-id: req.params.query-id}, {$set: {status: false}}
    return die res err if !!err

    (err, queries-updated) <- query-database.collection \queries .update {parent-id: req.params.query-id}, {$set: {parent-id: results.0.parent-id}}, {multi:true}
    return die res err if !!err    

    res.end results.0.parent-id

# set the status property of all the queries in the branch to false
app.get "/delete/branch/:branchId", (req, res)->

    (err, results) <- query-database.collection \queries .aggregate do 
        [
            {
                $match: 
                    branch-id: req.params.branch-id
            }
            {
                $project:
                    query-id: 1
                    parent-id: 1
            }
        ]
    return die res, err if !!err
    
    parent-id = difference do
        results |> map (.parent-id)
        results |> map (.query-id)

    # set the status of all queries in the branch to false i.e delete 'em all
    (err) <- query-database.collection \queries .update {branch-id: req.params.branch-id}, {$set: {status: false}}, {multi: true}
    return die res, err if !!err

    # reconnect the children to the parent of the branch
    criterion =
        $and: [
            {
                branch-id: $ne: req.params.branch-id
            }
            {
                parent-id: $in: results |> map (.query-id)
            }
        ]
    (err, queries-updated) <- query-database.collection \queries .update criterion, {$set: {parent-id: parent-id.0}}, {multi:true}
    return die res, err if !!err

    res.end parent-id.0

# transpile livescript, execute the mongo aggregate query and return the results
app.post \/execute, (req, res)->

    {server-name, database, collection, multi-query, query, cache, parameters = "{}"}:document = req.body    

    err, result <-  execute-query query-database, document
    return die res, err if !!err

    res.end JSON.stringify result, null, 4

# extract keywords from the latest record (for auto-completion)
app.get \/keywords/queryContext, (req, res) ->
    res.set \content-type, \application/json
    res.end JSON.stringify config.test-ips ++ ((get-all-keys-recursively get-query-context!, -> true) |> map dasherize)

#
app.get \/keywords/:serverName/:database/:collection, (req, res)->

    err, results <- execute-mongo-aggregation-pipeline req.params.server-name, req.params.database, req.params.collection,
        [
            {
                $sort: _id: -1
            }
            {
                $limit: 10
            }
        ]
    return die err, res if !!err

    collection-keywords = 
        results 
            |> concat-map (-> get-all-keys-recursively it, (k, v)-> typeof v != \function)
            |> unique

    res.set \content-type, \application/json
    res.end JSON.stringify collection-keywords ++ (collection-keywords |> map -> "$#{it}")

# return a list of all queries
app.get \/list, (req, res)->
    search-string = req.query?.name or ""
    (err, results) <- query-database.collection \queries .aggregate do
        [
            {
                $sort: _id: 1
            }
            {
                $group:
                    _id: 
                        branch-id: \$branchId
                        status: \$status
                    query-name: $last: \$queryName
                    query-id: $last: \$queryId
                    server-name: $last: \$serverName
                    database: $last: \$database
                    collection: $last: \$collection
                    creation-time: $first: \$creationTime
                    modification-time: $last: \$creationTime
            }
            {
                $match: 
                    "_id.status": true
                    query-name: {$regex: ".*#{search-string}.*", $options: \i}                    
            }
            {
                $project: 
                    _id: 0
                    branch-id: "$_id.branchId"
                    query-id: "$queryId"
                    query-name: 1
                    creation-time: 1
                    modification-time: 1
            }
        ]
    return die res, err if !!err
    res.end JSON.stringify results
    
# save the code to mongodb
app.post \/save, (req, res)->

    (err, results) <- query-database.collection \queries .aggregate do 
        [
            {
                $match:
                    branch-id: req.body.branch-id
                    status: true
            }
            {
                $project:
                    query-id: 1
                    parent-id: 1
            }
            {
                $sort:
                    _id: -1
            }            
        ]
    return die res, err.to-string! if !!err

    if !!results?.0 and results.0.query-id != req.body.parent-id

        index-of-parent-query = results |> find-index (.query-id == req.body.parent-id)

        queries-in-between = [0 til results.length] 
            |> map -> [it, results[it].query-id]
            |> filter ([index])-> index < index-of-parent-query
            |> map (.1)

        return die res, JSON.stringify {queries-in-between}
    
    (err, records) <- query-database.collection \queries .insert req.body <<< {creation-time: new Date!.get-time!, status: true}, {w: 1}
    return die res, err if !!err

    res.end JSON.stringify records.0

# deprecated route
app.get "/query/:queryId(\\d+)", (req, res)->
  encoded-id = base62.encode req.params.query-id
  res.redirect "/branch/#{encoded-id}/#{encoded-id}"

# redirect to the correct url based on query-id
app.get "/query/:queryId", (req, res)->
    err, {branch-id} <- get-query-by-id query-database, req.params.query-id
    return die res, err if !!err
    res.redirect "/branch/#{branch-id}/#{req.params.query-id}"

# returns all the queries that are in the same tree as that of req.params.query-id
app.get "/queries/tree/:queryId", (req, res)->

    (err, results) <- query-database.collection \queries .aggregate do 
        [
            {
                $match:
                    query-id: req.params.query-id
                    status: true
            }
            {
                $project:
                    tree-id: 1
            }
        ]        
    return die res, err if !!err
    return die res, "unable to find query #{req.params.query-id}" if results.length == 0

    (err, results) <- query-database.collection \queries .aggregate do 
        [
            {
                $match:
                    tree-id: results.0.tree-id
                    status: true
            }
            {
                $sort: _id: 1
            }
            {
                $project:
                    parent-id: 1
                    branch-id: 1
                    query-id: 1
                    query-name: 1
                    creation-time: 1
                    selected: $eq: [\$queryId, req.params.query-id]
            }
        ]

    return die res, err if !!err
    res.end JSON.stringify (results |> map ({creation-time}: query)-> {} <<< query <<< {creation-time: moment creation-time .format "ddd, DD MMM YYYY, hh:mm:ss a"}), null, 4

# uses query-id if present otherwise executes the latest query in the given branch
app.get "/rest/:layer/:cache/:branchId/:queryId?", (req, res)->    
    
    cache = match req.params.cache
    | \false => false
    | \true => true
    | otherwise => false    

    {query-id, branch-id} = req.params

    get-query = do ->
        return (get-query-by-id query-database, query-id) if !!query-id
        return (get-latest-query-in-branch query-database, branch-id) if !!branch-id
        (callback)-> callback "branch-id & query-id are undefined", null

    (err, {presentation}:document?) <- get-query
    return die res, err if !!err
    return die res, "unable to find query: #{req.params.query-id}" if document == null

    updated-document = document <<< {cache, parameters: req.query}

    run = (func)->
        err, result <- func
        return die res, err if !!err
        res.end JSON.stringify result, null, 4    

    return run (execute-query query-database, updated-document) if req.params.layer == \-
    return run (execute-and-transform-query query-database, updated-document) if req.params.layer == \transformation

    err, transformed-result <- execute-and-transform-query query-database, updated-document
    return die res, err if !!err    
    res.render do
        \public/presentation.html
        {
            transformed-result
            presentation: """
            draw = (view, result)->
            #{presentation |> Str.lines |> map (-> "    " + it) |> Str.unlines}
            """
            parameters: req.query
        }

# plot tree
app.get "/tree/:queryId", (req, res)-> res.render "public/tree.html", {query-id: req.params.query-id}

app.listen config.port
console.log "listening on port #{config.port}"



