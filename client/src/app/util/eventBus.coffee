
module = angular.module('gamEvolve.util.eventBus', [])


module.factory 'eventBus', ($rootScope) ->

  listen: (eventName, callback) ->
    $rootScope.$on eventName, callback

  send: ->
    $rootScope.$emit.apply($rootScope, arguments)


createEventType = (name) ->

  module.factory name, (eventBus) ->

    listen: (listener) ->
      eventBus.listen name, (event, data) ->
        listener(data)

    send: (data) ->
      eventBus.send(name, data)


createEventType('GameVersionUpdatedEvent')
createEventType('SwitchRenamedEvent')
createEventType('ProcessorRenamedEvent')
createEventType('TransformerRenamedEvent')
