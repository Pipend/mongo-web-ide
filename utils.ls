{concat-map, keys} = require \prelude-ls
{compile} = require \LiveScript
vm = require \vm
{get-transformation-context} = require \./public/scripts/transformation-context


export compile-and-execute-livescript = (livescript-code, context)->

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

export get-all-keys-recursively = (object, filter-function)->
    keys object |> concat-map (key)-> 
        return [] if !filter-function key, object[key]
        return [key] ++ (get-all-keys-recursively object[key], filter-function)  if typeof object[key] == \object
        [key]


export get-query-by-id = (query-database, query-id, callback) !-->
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
    return callback null, results.0 if !!results?.0
    callback "query not found #{query-id}", null


export get-latest-query-in-branch = (query-database, branch-id, callback) !-->

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


export execute-and-transform-query = (query-database, execute-query, {parameters, transformation}:document, callback) !-->

    err, result <- execute-query query-database, document
    return callback err, null if !!err


    # apply transformation
    [err, func] = compile-and-execute-livescript "(#transformation\n)", (get-transformation-context! <<< (require \moment) <<< (require \prelude-ls) <<< parameters)

    return callback err if !!err
    try
        transformed-result = func result
    catch ex
        return callback ex.to-string!, null

    callback null, transformed-result