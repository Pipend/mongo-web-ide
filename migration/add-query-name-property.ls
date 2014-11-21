async = require \async
config = require \../config 
fs = require \fs
{concat-map, keys, map, filter} = require \prelude-ls
{MongoClient, ObjectID} = require \mongodb

(err, db) <- MongoClient.connect config.mongo, config.mongo-options
return console.log err if !!err

(err,res) <- db.collection \queries .aggregate []
return console.log err if !!err

(err) <- async.each do
	res |> map ({_id, name})->
		new-query = { 
			server-name: \ubuntu
			database: \MobiOne-events
			collection: \events
			query-name: name
		}
		[{_id}, {$set: new-query}]
	([where, new-query], callback)->
		(err, records-updated, status) <- db.collection \queries .update where, new-query
		return callback err if !!err
		console.log "records-updated = #{records-updated}, status = #{status}"

		callback null
return console.log err if !!err
console.log \done
