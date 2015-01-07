moment = require \moment

parse-date = (s) -> new Date s
today = -> ((moment!start-of \day .format "YYYY-MM-DDT00:00:00.000") + \Z) |> parse-date
{object-id-from-date, date-from-object-id} = require \./utils.ls

module.exports.get-transformation-context = ->

	# all functions defined here are accessibly by the transformation code
	{
		day-to-timestamp: -> it * 86400000
		parse-date: parse-date
		to-timestamp: (s) -> (moment (new Date s)).unix! * 1000
		today: today!
		object-id-from-date
		date-from-object-id
	}
