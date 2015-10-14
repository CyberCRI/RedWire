/**
 * This file/module contains all configuration for the build process.
 */
module.exports = {
    /**
     * The `build_dir` folder is where our projects are compiled during
     * development and the `compile_dir` folder is where our app resides once it's
     * completely built.
     */
    build_dir: '../server/public-dev',
    compile_dir: '../server/public-prod',

    /**
     * This is a collection of file patterns that refer to our app code (the
     * stuff in `src/`). These file paths are used in the configuration of
     * build tasks. `js` is all project javascript, less tests. `ctpl` contains
     * our reusable components' (`src/common`) template HTML files, while
     * `atpl` contains the same, but for our app's code. `html` is just our
     * main HTML file, `less` is our main stylesheet, and `unit` contains our
     * app's unit tests.
     */
    app_files: {
        js: [ 'src/**/*.js', '!src/**/*.spec.js', '!src/assets/**/*.js' ],
        jsunit: [ 'src/**/*.spec.js' ],

        coffee: [ 'src/**/*.coffee', '!src/**/*.spec.coffee' ],

        atpl: [ 'src/app/**/*.tpl.html' ],
        ctpl: [ 'src/common/**/*.tpl.html' ],

        html: [ 'src/index.html' ],
        less: 'src/less/main.less'
    },

  /**
   * This is the same as `app_files`, except it contains patterns that
   * reference vendor code (`vendor/`) that we need to place into the build
   * process somewhere. While the `app_files` property ensures all
   * standardized files are collected for compilation, it is the user's job
   * to ensure non-standardized (i.e. vendor-related) files are handled
   * appropriately in `vendor_files.js`.
   *
   * The `vendor_files.js` property holds files to be automatically
   * concatenated and minified with our project source files.
   *
   * The `vendor_files.css` property holds any CSS files to be automatically
   * included in our app.
   *
   * The `vendor_files.images` property holds any images to be copied along
   * with our app's assets. This structure is flattened, so it is not
   * recommended that you use wildcards.
   */
  vendor_files: {
    js: [
      'vendor/jquery/dist/jquery.js',
      'vendor/jquery-ui/jquery-ui.js',
      'vendor/bootstrap/js/bootstrap-tab.js',
      'vendor/angular/angular.js',
      'vendor/angular-mocks/angular-mocks.js',
      'vendor/angular-animate/angular-animate.js',
      'vendor/angular-bootstrap/ui-bootstrap-tpls.js',
      'vendor/angular-ui-router/release/angular-ui-router.js',
      'vendor/angular-ui-utils/modules/route/route.js',
      'vendor/angular-sanitize/angular-sanitize.js',
      'vendor/ace-builds/src-noconflict/ace.js',
      'vendor/ace-builds/src-noconflict/mode-css.js',
      'vendor/ace-builds/src-noconflict/worker-css.js',
      'vendor/ace-builds/src-noconflict/mode-html.js',
      'vendor/ace-builds/src-noconflict/worker-html.js',
      'vendor/ace-builds/src-noconflict/mode-javascript.js',
      'vendor/ace-builds/src-noconflict/worker-javascript.js',
      'vendor/ace-builds/src-noconflict/mode-json.js',
      'vendor/ace-builds/src-noconflict/worker-json.js',
      'vendor/ace-builds/src-noconflict/theme-twilight.js',
      'vendor/angular-ui-ace/ui-ace.js',
      'vendor/underscore/underscore.js',
      'vendor/underscore.string/lib/underscore.string.js',
      'vendor/flexy-layout/flexy-layout.debug.js',
      'vendor/angular-ui-sortable/sortable.js',
      'vendor/angular-file-dnd/dist/angular-file-dnd.js',
      'vendor/angular-xeditable/dist/js/xeditable.js',
      'vendor/rivets/dist/rivets.js',
      'vendor/sylvester/sylvester.src.js',
      'vendor/Chart.js/Chart.js',
      'vendor/jsoneditor/jsoneditor.js',
      'vendor/moment/moment.js',
      'vendor/mousetrap/mousetrap.js',
      'vendor/webaudiox/build/webaudiox.js',
      'vendor/webaudiox/examples/vendor/jsfx/audio.js',
      'vendor/webaudiox/examples/vendor/jsfx/jsfx.js',
      'vendor/webaudiox/examples/vendor/jsfx/jsfxlib.js',
      'vendor/dragster/lib/dragster.js',
      'vendor/bowser/bowser.js',
      'vendor/sat-js/SAT.js',
      'vendor/angulartics/src/angulartics.js',
      'vendor/angulartics/src/angulartics-ga.js',
      'vendor/gifshot/build/gifshot.js',
      'vendor/localforage/dist/localforage.js'
    ],
    css: [
      'vendor/flexy-layout/src/flexyLayout.css',
      'vendor/angular-xeditable/dist/css/xeditable.css',
      'vendor/jsoneditor/jsoneditor.css'
    ],
    images: [
      'vendor/jsoneditor/img/jsoneditor-icons.png'
    ]
  }
};
