async = require \async
config = require \./config 
fs = require \fs
{concat-map, keys, map, filter} = require \prelude-ls
{MongoClient, ObjectID} = require \mongodb

(err, db) <- MongoClient.connect config.mongo, config.mongo-options
return console.log err if !!err
console.log "successfully connected to #{config.mongo}"


(err, queries) <- fs.readdir \./tmp

(err) <- async.each do
    queries
    (query)->
        (err, data) <- fs.read-file "./tmp/#{query}"
        return console.log err if !!err

        data = JSON.parse data
        data.transformation = data.transformation-code
        data.presentation = data.presentation-code
        delete data.transformation-code
        delete data.presentation-code
        (err, records) <- db.collection \queries .insert data <<< {creation-time: new Date!.get-time!}, {w: 1}
        return console.log err if !!err

        console.log "inserted #{query}"
