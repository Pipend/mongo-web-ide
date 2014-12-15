async = require \async
base62 = require \base62
config = require \../config 
fs = require \fs
{concat-map, keys, map, filter} = require \prelude-ls
{MongoClient, ObjectID} = require \mongodb

(err, db) <- MongoClient.connect config.mongo, config.mongo-options
return console.log err if !!err

console.log "successfully connected to #{config.mongo}"

(err, results) <- db.collection \queries .aggregate do 
	[
		{
			$match:
				treeId: $exists: false
				queryId: $ne: null				
		}
		{
			$sort:
				creation-time: 1
		}
		{
			$group:
				_id: "$queryId"
				mongo-id: $last: "$_id"				
		}
		{
			$project:
				_id: 0
				query-id: "$_id"
				mongo-id: 1
		}		
	]
return console.log err if !!err
console.log "number of queries = #{results.length}"

# remove query histroy
err, number-of-records-removed <- db.collection \queries .remove {_id: $nin: results |> map (.mongo-id)}, {w: 1} 
return console.log err if !!err
console.log "number of records removed = #{number-of-records-removed}"

# update the queries with a new query-id, branch-id, tree-id & parent-id
err <- async.each-series do 
	results
	({query-id, mongo-id}, callback)->
		encoded-time = base62.encode query-id
		(err, records-updated, status) <- db.collection \queries .update do 
			{_id: ObjectID mongo-id}
			{
				$set:
					query-id: encoded-time
					parent-id: null
					branch-id: encoded-time
					tree-id: encoded-time
			}
		return callback err if !!err
		console.log "records-updated = #{records-updated}, status = #{status}"
		callback null
console.log err if !!err