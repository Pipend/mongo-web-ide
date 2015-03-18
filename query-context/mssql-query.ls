{id, concat-map, dasherize, difference, each, filter, find, find-index, foldr1, Obj, keys, map, group-by, obj-to-pairs, pairs-to-obj, Str, unique, any} = require \prelude-ls
config = require \./../config
sql = require \mssql

export get-query-context = ->
	{} <<< (require \./default-query-context.ls)!

query-sql = (connection-config, query, callback) ->
	connection = new sql.Connection connection-config, (err)->
		return callback err if !!err
		(err, records) <- (new sql.Request connection).query query
		connection.close!
		return callback err if !!err
		callback null, records

export query = ({query-database, execute-query}:connection, query, parameters, query-id, callback) ->
	(Obj.keys parameters) |> each (key) ->
		query := query.replace "$#{key}$", parameters[key]
	query-sql config.mssql.connection-strings.0, query, callback

export cancel = (query-id, callback) !-->
	callback "Not Implemented", null

export keywords = ({query-database}:connection, callback) !-->
	#http://192.168.1.2:3001/rest/transformation/true/p6HlayD
	err, result <- query-sql config.mssql.connection-strings.0, "SELECT TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS"
	return callback err, null if !!err

	result := result
	|> group-by (.TABLE_SCHEMA)
	|> Obj.map group-by (.TABLE_NAME) 
	|> Obj.map Obj.map map (.COLUMN_NAME)
	|> Obj.map obj-to-pairs >> concat-map ([table, columns]) -> [table] ++ do -> columns |> map ("#{table}." +)
	|> obj-to-pairs
	|> concat-map (.1)

	callback null, <[SELECT GROUP BY TOP ORDER WITH DISTINCT INNER OUTER JOIN]> ++ result