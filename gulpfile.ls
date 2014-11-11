gulp = require \gulp
gulpif = require \gulp-if
gulp-livescript = require \gulp-livescript
livereload = require \gulp-livereload
nodemon = require \gulp-nodemon
stylus = require \gulp-stylus

gulp.task \compilation, ->
    gulp.src 'public/*.styl'
    .pipe stylus!
    .pipe gulp.dest 'public/'

    gulp.src 'public/*.ls'
    .pipe gulp-livescript {}
    .pipe gulp.dest 'public/'

gulp.task \watch, ->
    gulp.watch <[public/*.styl public/*.ls]>, ['compilation']

gulp.task \develop, ->
    livereload.listen!
    nodemon {        
        exec-map: ls: \lsc
        ext: \ls
        ignore: <[public/*]>
        script: \./server.ls
    } .on \restart, -> livereload.changed!

gulp.task \default, <[compilation watch develop]>
