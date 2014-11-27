module.exports.get-transformation-context = ->

	# all functions defined here are accessibly by the transformation code
	{
		day-to-timestamp: -> it * 86400000
	}
