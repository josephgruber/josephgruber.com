var autoprefixer  = require('autoprefixer');
var browserSync   = require('browser-sync').create();
var cleancss      = require('gulp-clean-css');
var concat        = require('gulp-concat');
var cp            = require('child_process');
var critical      = require('critical');
var del           = require('del');
var gulp          = require('gulp');
var gzip          = require('gulp-gzip');
var imagemin      = require('gulp-imagemin');
var log           = require('fancy-log');
var mozjpeg       = require('imagemin-mozjpeg');
var postcss       = require('gulp-postcss');
var rename        = require('gulp-rename');
var rev           = require('gulp-rev');
var revRewrite    = require('gulp-rev-rewrite');
var sass          = require('gulp-ruby-sass');
var uglify        = require('gulp-uglify');
var uncss         = require('postcss-uncss');
var webp          = require('imagemin-webp');

// Include paths file.
var paths = require('./_assets/gulp/paths.js');

// Uses Sass compiler to process styles, adds vendor prefixes, minifies, then
// outputs file to the appropriate location.
gulp.task('build:styles', function() {
  return sass(paths.sassFiles + '/main.scss', {
    style: 'compressed',
    trace: true,
    loadPath: [paths.sassFiles]
  })
    .pipe(postcss([autoprefixer({ browsers: ['last 2 versions'] })]))
    .pipe(cleancss())
    .pipe(rev())
    .pipe(gulp.dest(paths.jekyllCssFiles))
    .pipe(gulp.dest(paths.siteCssFiles))
    .pipe(rev.manifest(paths.gulpFiles + '/rev-manifest.json', {
      base: paths.gulpFiles,
      merge: true
    }))
    .pipe(gulp.dest(paths.gulpFiles))
    .pipe(browserSync.stream())
    .on('error', log.error);
});

// Builds critical CSS, to be included in head.html.
gulp.task('build:styles:critical', function() {
  return critical.generate({
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
  return gulp.src(paths.siteCssFiles + '/*.css')
    .pipe(postcss([uncss({
      html: ['./_site/**/*.html'],
      htmlroot: paths.siteDir,
      ignore: ['.webp .panel-cover', '.no-webp .panel-cover', '.animated', '.fadeIn', '.bounceInDown', '.navigation-wrapper.visible']
    })]))
    .pipe(gulp.dest(paths.jekyllCssFiles))
    .pipe(gulp.dest(paths.siteCssFiles))
    .pipe(browserSync.stream())
    .on('error', log.error);
});

// Gzip's main CSS file
gulp.task('build:styles:compress', function() {
  return gulp.src(paths.jekyllCssFiles + '/*.css')
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
gulp.task('build:scripts', function() {
  return gulp.src([
      paths.jsFiles + '/lib' + paths.jsPattern,
      paths.jsFiles + '/*.js'
  ])
      .pipe(concat('main.js'))
      .pipe(uglify())
      .pipe(rev())
      .pipe(gulp.dest(paths.jekyllJsFiles))
      .pipe(gulp.dest(paths.siteJsFiles))
      .pipe(rev.manifest(paths.gulpFiles + '/rev-manifest.json', {
        base: paths.gulpFiles
      }))
      .pipe(gulp.dest(paths.gulpFiles))
      .on('error', log.error);
});

// Gzip's main JS file
gulp.task('build:scripts:compress', function() {
  return gulp.src(paths.jekyllJsFiles + '/*.js')
    .pipe(gzip({ append: false }))
    .pipe(gulp.dest(paths.jekyllJsFiles))
    .pipe(gulp.dest(paths.siteJsFiles));
});

// Deletes processed JS.
gulp.task('clean:scripts', function(done) {
  del([paths.jekyllJsFiles + '/*.js', paths.siteJsFiles + '/*.js']);
  done();
});

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

// Convert all png and jpg images to WebP format
gulp.task('build:images:webp', function() {
  return gulp.src(paths.jekyllImageFilesGlob)
    .pipe(imagemin([
      webp()
    ]))
    .pipe(rename({ extname: '.webp' }))
    .pipe(gulp.dest(paths.jekyllImageFiles))
    .pipe(gulp.dest(paths.siteImageFiles))
    .pipe(browserSync.stream());
});

// Copy favicon and manifests to image directories
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
gulp.task('build:images', gulp.series('build:images:main', gulp.parallel('build:images:webp', 'build:images:manifest')));

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

gulp.task('build:compress', gulp.parallel('build:styles:compress', 'build:scripts:compress'));

gulp.task('build:rev-rewrite', function() {
  var manifest = gulp.src('./_assets/gulp/rev-manifest.json');

  return gulp.src(paths.siteHtmlFilesGlob)
    .pipe(revRewrite({ manifest }))
    .pipe(gulp.dest(paths.siteDir));
});

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
gulp.task('clean', gulp.parallel('clean:jekyll', 'clean:images', 'clean:scripts', 'clean:fonts', 'clean:styles'));

// Builds site anew.
gulp.task('build', gulp.series('clean', 'build:scripts', gulp.parallel('build:images', 'build:styles', 'build:fonts'), 'build:jekyll', 'build:rev-rewrite', 'build:styles:uncss', 'build:compress', 'deploy:aws'));

// Builds site anew.
gulp.task('build-dev', gulp.series('clean', 'build:scripts', gulp.parallel('build:images', 'build:styles', 'build:fonts'), 'build:jekyll', 'build:rev-rewrite', 'build:styles:uncss'));

// Special tasks for building and then reloading BrowserSync.
gulp.task('build:jekyll:watch', gulp.series('build:jekyll', function(done) {
  browserSync.reload();
  done();
}));

gulp.task('build:scripts:watch', gulp.series('build:scripts', function(done) {
  browserSync.reload();
  done();
}));

// Static Server + watching files.
gulp.task('serve', gulp.series('build-dev', function() {
  browserSync.init({
    server: paths.siteDir,
    ghostMode: false, // Toggle to mirror clicks, reloads etc. (performance)
    logFileChanges: true,
    logLevel: 'debug',
    open: true        // Toggle to automatically open page when starting.
  });

  // Watch site settings.
  gulp.watch('_config.yml', gulp.parallel('build:jekyll:watch'));

  // Watch .scss files; changes are piped to browserSync.
  gulp.watch('_assets/style/**/*.scss', gulp.parallel('build:styles'));

  // Watch .js files.
  gulp.watch('_assets/js/**/*.js', gulp.parallel('build:scripts:watch'));

  // Watch image files; changes are piped to browserSync.
  gulp.watch('_assets/img/**/*', gulp.parallel('build:images'));

  // Watch posts.
  gulp.watch('_posts/**/*.+(md|markdown|MD)', gulp.parallel('build:jekyll:watch'));

  // Watch html and markdown files.
  gulp.watch(['**/*.+(html|md|markdown|MD)', '!_site/**/*.*'], gulp.parallel('build:jekyll:watch'));
}));

// Default Task: builds site.
gulp.task('default', gulp.series('build'));
