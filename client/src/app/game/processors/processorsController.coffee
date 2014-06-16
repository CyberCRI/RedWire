angular.module('gamEvolve.game.processors', [
  'ui.bootstrap',
])
.controller 'ProcessorsListCtrl', ($scope, $modal, currentGame, ProcessorRenamedEvent) ->
  # Get the processors object from the currentGame service, and keep it updated
  $scope.processors = {}
  $scope.processorNames = []

  # Bring currentGame into scope so we can watch it 
  updateProcessors = ->
    if currentGame.version?.processors?
      $scope.processors = currentGame.version.processors
      $scope.processorNames = _.keys(currentGame.version.processors)
  $scope.currentGame = currentGame
  $scope.$watch("currentGame.localVersion", updateProcessors, true)

  $scope.newProcessor = (processorName) ->
    processor: processorName
    pins:
      in: {}
      out: {}

  $scope.remove = (name) ->
    if window.confirm("Are you sure you want to delete this processor?")
      delete currentGame.version.processors[name]
      currentGame.updateLocalVersion()

  $scope.add = () ->
    addProcessorDialog = $modal.open
      backdrop: "static"
      templateUrl: 'game/processors/editProcessor.tpl.html'
      size: "lg"
      controller: 'EditProcessorDialogCtrl'
      resolve:
        # This object will be provided to the dialog as a dependency, and serves to communicate between the two
        processor: ->
          {
            model:
              name: ""
              pinDefs: {}
              update: ""
            done: (model) ->
              currentGame.version.processors[model.name] = 
                pinDefs: model.pinDefs
                update: model.update
              currentGame.updateLocalVersion()

              addProcessorDialog.close()
            cancel: ->
              addProcessorDialog.close()
          }

  $scope.edit = (processorName) -> 
    processor = currentGame.version.processors[processorName]
    editProcessorDialog = $modal.open
      backdrop: true
      dialogFade: true
      backdrop: "static"
      templateUrl: 'game/processors/editProcessor.tpl.html'
      size: "lg"
      controller: 'EditProcessorDialogCtrl'
      resolve:
        # This object will be provided to the dialog as a dependency, and serves to communicate between the two
        processor: ->
          {
            model:
              name: processorName
              pinDefs: processor.pinDefs
              update: processor.update
            done: (model) ->
              # Handle rename case
              if model.name isnt processorName
                ProcessorRenamedEvent.send
                  oldName: processorName
                  newName: model.name
                delete currentGame.version.processors[processorName]

              currentGame.version.processors[model.name] = 
                pinDefs: model.pinDefs
                update: model.update
                
              currentGame.updateLocalVersion()
              editProcessorDialog.close()
            cancel: ->
              editProcessorDialog.close()
          }

.controller 'EditProcessorDialogCtrl', ($scope, liaison) ->
  # Convert between "pinDef form" used in game serialization and "pin form" used in GUI
  toPins = (pinDefs) ->
    for pinName, pinDef of pinDefs
      name: pinName
      direction: pinDef?.direction || "in"
      default: pinDef?.default || "" 
  toPinDefs = (pins) ->
    pinDefs = {}
    for pin in pins
      pinDefs[pin.name] = 
        direction: pin.direction 
        default: if pin.direction is "in" then pin.default else null
    return pinDefs

  $scope.DIRECTIONS = ["in", "inout", "out"]

  # Need to put 2-way data binding under an object
  $scope.exchange = {}
  $scope.exchange.name = liaison.model.name
  $scope.exchange.pins = toPins(liaison.model.pinDefs)
  $scope.exchange.updateText = liaison.model.update

  $scope.addPin = -> $scope.exchange.pins.push({ name: "", direction: "in" })
  $scope.removePin = (index) -> $scope.exchange.pins.splice(index, 1)

  # Reply with the new data
  $scope.done = -> liaison.done 
    name: $scope.exchange.name
    pinDefs: toPinDefs($scope.exchange.pins)
    update: $scope.exchange.updateText
  $scope.cancel = -> liaison.cancel() 
