async = require \async
browserify = require \browserify
cheerio = require \cheerio
{browserify-debug-mode} = require \./config
fs = require \fs
gulp = require \gulp
gulp-browserify = require \gulp-browserify 
gulp-livescript = require \gulp-livescript
nodemon = require \gulp-nodemon
stylus = require \gulp-stylus
{basename, dirname, extname} = require \path
{filter, flatten, each, map, Str} = require \prelude-ls
source = require \vinyl-source-stream
watchify = require \watchify

get-html-files = (directory, callback)->
    (err, files) <- fs.readdir directory
    return callback err, null if !!err
    callback null, (files 
        |> filter -> (extname it) == \.html
        |> map -> "#{directory}/#{it}"
    )

get-scripts-to-browserify = (html-files, callback)->
    (err, results) <- async.map do 
        html-files
        (file, callback)->
            (err, data) <- fs.read-file file
            return callback err, null if !!err
            $ = cheerio.load "#{data}"
            callback null, ($ "script[src]" 
                |> map -> $ it .attr \src
                |> filter -> !!it and it.trim!.length > 0
            )
    return callback err, null if !!err
    callback null, (results |> flatten |> filter -> !!it)

watch-entries = (entries, callback)->
    (err) <- async.each-series do 
        entries
        ({directory, file}, callback)->
            b = browserify watchify.args <<< {debug: browserify-debug-mode}
            b.add "#{directory}/#{file}.ls"
            b.transform \liveify    
            b.transform \cssify
            w = watchify b
            bundle = ->
                w.bundle!
                    .on \error, -> console.log arguments
                    .pipe source "#{file}.js"
                    .pipe gulp.dest directory
            w.on \update, bundle
            bundle!
            callback null
    return callback err if !!err
    callback null

gulp.task \compilation, ->
    gulp.src 'public/styles/*.styl'
    .pipe stylus!
    .pipe gulp.dest 'public/styles/'    

gulp.task \watch, ->

    gulp.watch <[public/styles/*.styl]>, ['compilation']

    (err, html-files) <- get-html-files \./public/
    return console.log err if !!err

    (err, scripts) <- get-scripts-to-browserify html-files
    return console.log err if !!err

    entries = scripts |> map -> {
        directory: ".#{dirname it}"
        file: (basename it).replace (extname it), ""
    }

    (err) <- watch-entries entries
    return console.log err if !!err
    
gulp.task \develop, ->
    nodemon {        
        exec-map: ls: \lsc
        ext: \ls
        ignore: <[public/*]>
        script: \./server.ls
    }

gulp.task \default, <[compilation watch develop]>
