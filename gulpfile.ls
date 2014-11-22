gulp = require \gulp
gulp-browserify = require \gulp-browserify 
gulp-livescript = require \gulp-livescript
livereload = require \gulp-livereload
nodemon = require \gulp-nodemon
stylus = require \gulp-stylus

gulp.task \compilation, ->
    gulp.src 'public/styles/*.styl'
    .pipe stylus!
    .pipe gulp.dest 'public/styles/'

    gulp.src 'public/scripts/*.ls'
    .pipe gulp-livescript {bare: true}
    .pipe gulp-browserify {
        transform: [\liveify]
        debug: true
    }
    .pipe gulp.dest 'public/scripts/'

gulp.task \watch, ->
    gulp.watch <[public/styles/*.styl public/scripts/*.ls]>, ['compilation']

gulp.task \develop, ->
    livereload.listen!
    nodemon {        
        exec-map: ls: \lsc
        ext: \ls
        ignore: <[public/*]>
        script: \./server.ls
    } .on \restart, -> livereload.changed!

gulp.task \default, <[compilation watch develop]>
