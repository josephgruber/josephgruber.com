var gulp = require('gulp');
var download = require('gulp-download');
var rename = require('gulp-rename');
var vinylPaths = require('vinyl-paths');
var del = require('del');
var imagemin = require('gulp-imagemin');
var imageminMozjpeg = require('imagemin-mozjpeg');

// Directory locations.
var paths = {};
paths.imageFiles = '_assets/img/';
paths.imageOutput = 'assets/img/'
paths.jsOutput = 'assets/js/';

// Download latest version of Google Analytics JavaScript file
gulp.task('build:fetch-analytics', function() {
  return download('https://www.googletagmanager.com/gtag/js?id=UA-12826609-1')
    .pipe(gulp.dest(paths.jsOutput))
    .pipe(vinylPaths(del))
    .pipe(rename('google-analytics.js'))
    .pipe(gulp.dest(paths.jsOutput));
});

// Optimize images in assets directory.
gulp.task('build:images', function() {
  return gulp.src(paths.imageFiles + '*.+(jpg|JPG|jpeg|JPEG|png|PNG|svg|SVG|gif|GIF|webp|WEBP|tif|TIF)')
  .pipe(imagemin([
      imagemin.gifsicle('interlaced: true'),
      imagemin.optipng('optimizationLevel: 3'),
      imagemin.svgo('plugins: [{ removeDesc: true }]'),
      imageminMozjpeg('quality: 75')
    ], 'verbose: false'))
  .pipe(gulp.dest(paths.imageOutput));
});

// Builds site
gulp.task('build', ['build:fetch-analytics', 'build:images']);

// Default Task: builds site.
gulp.task('default', ['build']);
