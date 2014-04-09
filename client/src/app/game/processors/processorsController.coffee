angular.module('gamEvolve.game.processors', [
  'ui.bootstrap',
])
.controller 'ProcessorsListCtrl', ($scope, $dialog, currentGame) ->
  # Get the processors object from the currentGame service, and keep it updated
  $scope.processors = {}
  $scope.processorNames = []

  # Bring currentGame into scope so we can watch it 
  updateProcessors = ->
    if currentGame.version?.processors?
      $scope.processors = currentGame.version.processors
      $scope.processorNames = _.keys(currentGame.version.processors)
  $scope.currentGame = currentGame
  $scope.$watch('currentGame', updateProcessors, true)

  $scope.remove = (name) ->
    if window.confirm("Are you sure you want to delete this processor?")
      delete currentGame.version.processors[name]

  $scope.add = () ->
    addProcessorDialog = $dialog.dialog
      backdrop: true
      dialogFade: true
      backdropFade: true
      backdropClick: false
      templateUrl: 'game/processors/editProcessor.tpl.html'
      dialogClass: "large-modal"
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

              addProcessorDialog.close()
            cancel: ->
              addProcessorDialog.close()
          }
    addProcessorDialog.open()

  $scope.edit = (processorName) -> 
    processor = currentGame.version.processors[processorName]
    editProcessorDialog = $dialog.dialog
      backdrop: true
      dialogFade: true
      backdropFade: true
      backdropClick: false
      templateUrl: 'game/processors/editProcessor.tpl.html'
      dialogClass: "large-modal"
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
                delete currentGame.version.processors[processorName]

              currentGame.version.processors[model.name] = 
                pinDefs: model.pinDefs
                update: model.update

              editProcessorDialog.close()
            cancel: ->
              editProcessorDialog.close()
          }
    editProcessorDialog.open()

.controller 'EditProcessorDialogCtrl', ($scope, processor) ->
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
  $scope.name = processor.model.name
  $scope.pins = toPins(processor.model.pinDefs)
  $scope.updateText = processor.model.update

  $scope.addPin = -> $scope.pins.push({ name: "", direction: "in" })
  $scope.removePin = (index) -> $scope.pins.splice(index, 1)

  # Reply with the new data
  $scope.done = -> processor.done 
    name: $scope.name
    pinDefs: toPinDefs($scope.pins)
    update: $scope.updateText
  $scope.cancel = -> processor.cancel() 
