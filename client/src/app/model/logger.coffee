angular.module('gamEvolve.logger', [])

.factory 'logger', ($window) ->

    logToConsole: (type, message) -> $window.console[type.toLowerCase()](message)
