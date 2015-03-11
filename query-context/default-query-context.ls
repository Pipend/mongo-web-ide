moment = require \moment
# get-default-query-context
module.exports = ->
    parse-date = (s) -> new Date s
    to-timestamp = (s) -> (moment (new Date s)).unix! * 1000
    today = -> ((moment!start-of \day .format "YYYY-MM-DDT00:00:00.000") + \Z) |> parse-date
    {
        moment
        parse-date
        to-timestamp
        get-today: today
        today: today!
    }