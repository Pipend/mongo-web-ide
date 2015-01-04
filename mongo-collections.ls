async = require \async
config = require \./config
fs = require \fs
moment = require \moment
{MongoClient, ObjectID, Server} = require \mongodb
{concat-map, dasherize, difference, each, filter, find, find-index, keys, map, Str, unique} = require \prelude-ls
request = require \request

get-databases = (mongodb-ip, mongodb-port, callback)->

	(err, db) <- MongoClient.connect "mongodb://#{mongodb-ip}:#{mongodb-port}/test/", {}
	return callback err, null if !!err

	err, {databases} <- db.admin!.list-databases
	db.close!
	return callback err, null if !!err

	err, databases <- async.map do 
		databases |> map (.name)
		(database, callback)->

			err, db <- MongoClient.connect "mongodb://#{mongodb-ip}:#{mongodb-port}/#{database}/"
			return callback err if !!err

			err, collections <- db.collection-names
			db.close!
			return callback err if !!err
			callback null, {database, collections}			

	return callback err, null if !!err	
	callback null databases

err, databases <- async.map do 
	config.connection-strings
	({name, host, port}, callback)->
		err, databases <- get-databases host, port
		return callback err, null if !!err
		callback null, {name, databases}

return console.log err if !!err
console.log JSON.stringify databases, null, 4