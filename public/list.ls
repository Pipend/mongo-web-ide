{each, map, find, filter, is-it-NaN, sort-by, unique-by} = require \prelude-ls


$ ->
	local-queries = [0 to local-storage.length] 
		|> map -> local-storage.key it
		|> map -> 
			data = local-storage.get-item it
			{query-name}? = JSON.parse data
			{query-id: (parse-int it), query-name}
		|> filter ({query-id})->
			server-version = queries |> find -> it.query-id == query-id
			(typeof server-version == \undefined) || server-version.status

	(queries |> filter (.status == true)) ++ local-queries 
		|> unique-by (.query-id)
		|> filter -> !!it.query-id  && !is-it-NaN it.query-id
		|> sort-by (.query-id)
		|> each ->
			link-tag = $ "<a/>" .attr \href, "/#{it.query-id}" .html "#{it.query-name} (#{it.query-id})"
			list-element = $ "<li/>" .append link-tag
			$ \ol .append list-element
