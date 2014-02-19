angular.module('gamEvolve.model.history', [])
.factory 'gameHistory', ->
  meta:
    # Need to update the version at each change of the data
    version: 0
  data:
    # TODO: don't store the entire model and serviceData each time! Use patches, or better yet, persistant data structures
    frames: [ ]
    compilationErrors: []

  reset: ->
    @data.frames = []
    @data.compilationErrors = []
    @meta.version = 0
