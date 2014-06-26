var files = require('./build.config.js')['vendor_files'].js;
files.push('src/app/**/*.js');
files.push('src/app/**/*.coffee');
files.push('src/tests/**/*.spec.coffee');

module.exports = function (config) {

    config.set({

        // base path, that will be used to resolve files and exclude
        basePath: '',

        frameworks: ['jasmine'],

        // list of files / patterns to load in the browser
        files: files,

        preprocessors: {
            'src/**/*.coffee': ['coffee']
        },

        coffeePreprocessor: {
            // options passed to the coffee compiler
            options: {
                bare: true,
                sourceMap: false
            },
            // transforming the filenames
            transformPath: function(path) {
                return path.replace(/\.coffee$/, '.js');
            }
        },

        // web server port
        // CLI --port 9876
        port: 9876,

        // enable / disable colors in the output (reporters and logs)
        // CLI --colors --no-colors
        colors: true,

        // level of logging
        // possible values: config.LOG_DISABLE || config.LOG_ERROR || config.LOG_WARN || config.LOG_INFO || config.LOG_DEBUG
        // CLI --log-level debug
        logLevel: config.LOG_INFO,

        // enable / disable watching file and executing tests whenever any file changes
        // CLI --auto-watch --no-auto-watch
        autoWatch: true,

        // Start these browsers, currently available:
        // - Chrome
        // - ChromeCanary
        // - Firefox
        // - Opera
        // - Safari (only Mac)
        // - PhantomJS
        // - IE (only Windows)
        // CLI --browsers Chrome,Firefox,Safari
        browsers: [process.env.TRAVIS ? 'Firefox' : 'Chrome'],

        // If browser does not capture in given timeout [ms], kill it
        // CLI --capture-timeout 5000
        captureTimeout: 20000,

        // Auto run tests on start (when browsers are captured) and exit
        // CLI --single-run --no-single-run
        singleRun: false,

        // report which specs are slower than 500ms
        // CLI --report-slower-than 500
        reportSlowerThan: 500,

        plugins: [
            'karma-jasmine',
            'karma-chrome-launcher',
            'karma-coffee-preprocessor'
        ]
    });
};
