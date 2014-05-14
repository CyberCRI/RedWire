
GameVersionUpdatedEvent = 'GameVersionUpdatedEvent'

angular.module('gamEvolve.util.eventBus', [])


.factory 'eventBus', ($rootScope) ->

  listen: (eventName, callback) ->
    $rootScope.$on eventName, callback

  send: ->
    $rootScope.$emit.apply($rootScope, arguments)


.factory GameVersionUpdatedEvent, (eventBus) ->

  listen: (listener) ->
    eventBus.listen GameVersionUpdatedEvent, (event, newVersion) ->
      listener(newVersion)

  send: (gameVersion) ->
    eventBus.send(GameVersionUpdatedEvent, gameVersion)
