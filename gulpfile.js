var autoprefixer  = require('autoprefixer');
var browserSync   = require('browser-sync').create();
var cleancss      = require('gulp-clean-css');
var concat        = require('gulp-concat');
var cp            = require('child_process');
var critical      = require('critical');
var del           = require('del');
var download      = require('gulp-download');
var gulp          = require('gulp');
var gzip          = require('gulp-gzip');
var imagemin      = require('gulp-imagemin');
var log           = require('fancy-log');
var mozjpeg       = require('imagemin-mozjpeg');
var postcss       = require('gulp-postcss');
var rename        = require('gulp-rename');
var runSequence   = require('run-sequence');
var sass          = require('gulp-ruby-sass');
var uglify        = require('gulp-uglify');
var uncss         = require('postcss-uncss');
var vinylPaths    = require('vinyl-paths');

// Include paths file.
var paths = require('./_assets/gulp/paths.js');

// Uses Sass compiler to process styles, adds vendor prefixes, minifies, then
// outputs file to the appropriate location.
gulp.task('build:styles', function() {
  return sass(paths.sassFiles + '/main.scss', {
    style: 'compressed',
    trace: true,
    loadPath: [paths.sassFiles]
  }).pipe(postcss([autoprefixer({ browsers: ['last 2 versions'] })]))
    .pipe(cleancss())
    .pipe(gulp.dest(paths.jekyllCssFiles))
    .pipe(gulp.dest(paths.siteCssFiles))
    .pipe(browserSync.stream())
    .on('error', log.error);
});

// Builds critical CSS, to be included in head.html.
gulp.task('build:styles:critical', function() {
  critical.generate({
    base: '_site/',
    src: 'index.html',  // Extract critical path CSS for index.html
    css: [paths.jekyllCssFiles + '/main.css'],
    dest: '../_includes/critical.css',
    minify: true,
    include: [/cc_/],
    ignore: ['@font-face']
  });
});

// Remove unused classes in CSS
gulp.task('build:styles:uncss', function() {
  return gulp.src(paths.siteCssFiles + '/main.css')
    .pipe(postcss([uncss({
      html: ['./_site/**/*.html'],
      htmlroot: paths.siteDir
    })]))
    .pipe(gulp.dest(paths.jekyllCssFiles))
    .pipe(gulp.dest(paths.siteCssFiles))
    .pipe(browserSync.stream())
    .on('error', log.error);
});

// Gzip's main CSS file
gulp.task('build:styles:compress', function() {
  return gulp.src(paths.jekyllCssFiles + '/main.css')
    .pipe(gzip({ append: false }))
    .pipe(gulp.dest(paths.jekyllCssFiles))
    .pipe(gulp.dest(paths.siteCssFiles));
});

// Deletes CSS.
gulp.task('clean:styles', function(done) {
  del([paths.jekyllCssFiles,
    paths.siteCssFiles
  ]);
  done();
});

// Concatenates and uglifies global JS files and outputs result to the
// appropriate location.
gulp.task('build:scripts:main', function() {
  return gulp.src([
      paths.jsFiles + '/lib' + paths.jsPattern,
      paths.jsFiles + '/*.js'
  ])
      .pipe(concat('main.js'))
      .pipe(uglify())
      .pipe(gulp.dest(paths.jekyllJsFiles))
      .pipe(gulp.dest(paths.siteJsFiles))
      .on('error', log.error);
});

// Download latest version of Google Analytics JavaScript file for caching
gulp.task('build:scripts:analytics', function() {
  return download('https://www.googletagmanager.com/gtag/js?id=UA-12826609-1')
    .pipe(gulp.dest(paths.jekyllJsFiles))
    .pipe(vinylPaths(del))
    .pipe(rename('google-analytics.js'))
    .pipe(uglify())
    .pipe(gulp.dest(paths.jekyllJsFiles))
    .pipe(gulp.dest(paths.siteJsFiles));
});

// Gzip's main JS file
gulp.task('build:scripts:compress:main', function() {
  return gulp.src(paths.jekyllJsFiles + '/main.js')
    .pipe(gzip({ append: false }))
    .pipe(gulp.dest(paths.jekyllJsFiles))
    .pipe(gulp.dest(paths.siteJsFiles));
});

// Gzip's Google Analytics JS file
gulp.task('build:scripts:compress:analytics', function() {
  return gulp.src(paths.jekyllJsFiles + '/google-analytics.js')
    .pipe(gzip({ append: false }))
    .pipe(gulp.dest(paths.jekyllJsFiles))
    .pipe(gulp.dest(paths.siteJsFiles));
});

// Deletes processed JS.
gulp.task('clean:scripts', function(done) {
  del([paths.jekyllJsFiles + '/main.js', paths.siteJsFiles + '/main.js']);
  done();
});

// Builds all scripts.
gulp.task('build:scripts', ['build:scripts:main', 'build:scripts:analytics']);

// Optimizes images.
gulp.task('build:images:main', function() {
  return gulp.src(paths.imageFilesGlob)
    .pipe(imagemin([
      imagemin.gifsicle('interlaced: true'),
      imagemin.optipng('optimizationLevel: 5'),
      imagemin.svgo('plugins: [{ removeDesc: true }]'),
      mozjpeg('quality: 75', 'progressive: true')
    ], 'progressive: true', 'verbose: false'))
    .pipe(gulp.dest(paths.jekyllImageFiles))
    .pipe(gulp.dest(paths.siteImageFiles))
    .pipe(browserSync.stream());
});

gulp.task('build:images:manifest', function() {
  return gulp.src(paths.imageFiles + '/favicons/+(manifest.json|browserconfig.xml|favicon.ico)')
    .pipe(gulp.dest(paths.jekyllImageFiles + '/favicons/'))
    .pipe(gulp.dest(paths.siteImageFiles + '/favicons/'))
    .on('error', log.error);
});

// Deletes processed images.
gulp.task('clean:images', function(done) {
  del([paths.jekyllImageFiles, paths.siteImageFiles]);
  done();
});

// Builds all images
gulp.task('build:images', ['build:images:main', 'build:images:manifest']);

// Places fonts in proper location.
gulp.task('build:fonts', function() {
  return gulp.src(paths.fontFilesGlob)
    .pipe(rename(function(path) {path.dirname = '';}))
    .pipe(gulp.dest(paths.jekyllFontFiles))
    .pipe(gulp.dest(paths.siteFontFiles))
    .pipe(browserSync.stream())
    .on('error', log.error);
});

gulp.task('clean:fonts', function(done) {
  del([paths.jekyllFontFiles, paths.siteFontFiles]);
  done();
});

gulp.task('build:compress', ['build:styles:compress', 'build:scripts:compress:main', 'build:scripts:compress:analytics']);

gulp.task('build:jekyll', function(done) {
  return cp.spawn('bundle', ['exec', 'jekyll', 'build'], {stdio: 'inherit'})
    .on('close', done);
});

gulp.task('deploy:aws', function(done) {
  return cp.spawn('s3_website', ['push'], {stdio: 'inherit'})
    .on('close', done);
});

// Deletes the entire _site directory.
gulp.task('clean:jekyll', function(done) {
  del(['_site']);
  done();
});

// Main clean task.
// Deletes _site directory and processed assets.
gulp.task('clean', ['clean:jekyll',
  'clean:images',
  'clean:scripts',
  'clean:fonts',
  'clean:styles']);

// Builds site anew.
gulp.task('build', function(done) {
  runSequence('clean', ['build:scripts', 'build:images', 'build:styles', 'build:fonts'], 'build:jekyll', 'build:styles:uncss', 'build:compress', 'deploy:aws', done);
});

// Builds site anew.
gulp.task('build-dev', function(done) {
  runSequence('clean', ['build:scripts', 'build:images', 'build:styles', 'build:fonts'], 'build:jekyll', 'build:styles:uncss', done);
});

// Special tasks for building and then reloading BrowserSync.
gulp.task('build:jekyll:watch', ['build:jekyll'], function(done) {
  browserSync.reload();
  done();
});

gulp.task('build:scripts:watch', ['build:scripts'], function(done) {
  browserSync.reload();
  done();
});

// Static Server + watching files.
gulp.task('serve', ['build-dev'], function() {
  browserSync.init({
    server: paths.siteDir,
    ghostMode: false, // Toggle to mirror clicks, reloads etc. (performance)
    logFileChanges: true,
    logLevel: 'debug',
    open: true        // Toggle to automatically open page when starting.
  });

  // Watch site settings.
  gulp.watch(['_config.yml'], ['build:jekyll:watch']);

  // Watch .scss files; changes are piped to browserSync.
  gulp.watch('_assets/style/**/*.scss', ['build:styles']);

  // Watch .js files.
  gulp.watch('_assets/js/**/*.js', ['build:scripts:watch']);

  // Watch image files; changes are piped to browserSync.
  gulp.watch('_assets/img/**/*', ['build:images']);

  // Watch posts.
  gulp.watch('_posts/**/*.+(md|markdown|MD)', ['build:jekyll:watch']);

  // Watch html and markdown files.
  gulp.watch(['**/*.+(html|md|markdown|MD)', '!_site/**/*.*'], ['build:jekyll:watch']);
});

// Default Task: builds site.
gulp.task('default', ['build']);
