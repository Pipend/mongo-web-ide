async = require \async
browserify = require \browserify
fs = require \fs
gulp = require \gulp
gulp-browserify = require \gulp-browserify 
gulp-livescript = require \gulp-livescript
nodemon = require \gulp-nodemon
source = require \vinyl-source-stream
stylus = require \gulp-stylus
watchify = require \watchify
{filter, each, map} = require \prelude-ls

create-bundlers = do ->

    cache = {}

    (directory, callback)->

        return cache[directory] if !!cache[directory]

        (err, files) <- fs.readdir directory
        return callback err, null if !!err

        (err, results) <- async.map do 
            files |> filter -> (it.index-of \.ls) != -1
            (file, callback)->
                w = watchify {entries: ["#{directory}/#{file}"]}
                w.transform \liveify    
                bundle = ->
                    w.bundle {debug: true}
                        .on \error, -> console.log arguments
                        .pipe source (file.replace \.ls, \.js)
                        .pipe gulp.dest directory
                w.on \update, bundle
                callback null, {
                    file
                    bundle
                }

        return callback err, null if !!err
        cache[directory] = results
        callback null, results

gulp.task \compilation, ->
    gulp.src 'public/styles/*.styl'
    .pipe stylus!
    .pipe gulp.dest 'public/styles/'    

gulp.task \watch, ->
    gulp.watch <[public/styles/*.styl]>, ['compilation']
    
    (err, bundlers) <- create-bundlers \./public/scripts
    return console.log err if !!err
    bundlers |> each ({bundle})-> bundle!
    
gulp.task \develop, ->
    nodemon {        
        exec-map: ls: \lsc
        ext: \ls
        ignore: <[public/*]>
        script: \./server.ls
    }

gulp.task \default, <[compilation watch develop]>
