angular.module('gamEvolve.game.switches', [
  'ui.bootstrap',
])
.controller 'SwitchesListCtrl', ($scope, $dialog, currentGame) ->
  # Get the switches object from the currentGame service, and keep it updated
  $scope.switches = {}
  $scope.switchNames = []

  # Bring currentGame into scope so we can watch it 
  updateSwitches = ->
    if currentGame.version?.processes?
      $scope.switches = currentGame.version.processes
      $scope.switchNames = _.keys(currentGame.version.processes)
  $scope.currentGame = currentGame
  $scope.$watch('currentGame', updateSwitches, true)

  $scope.remove = (name) ->
    delete currentGame.version.processes[name]

  $scope.add = () ->
    addSwitchDialog = $dialog.dialog
      backdrop: true
      dialogFade: true
      backdropFade: true
      backdropClick: false
      templateUrl: 'game/switches/editSwitch.tpl.html'
      controller: 'EditSwitchDialogCtrl'
      resolve:
        # This object will be provided to the dialog as a dependency, and serves to communicate between the two
        switchIntermediary: ->
          {
            model:
              name: ""
              paramDefs: {}
              listActiveChildren: ""
              handleSignals: ""
            done: (model) ->
              currentGame.version.processes[model.name] = 
                paramDefs: model.paramDefs
                listActiveChildren: model.listActiveChildren
                handleSignals: model.handleSignals

              addSwitchDialog.close()
            cancel: ->
              addSwitchDialog.close()
          }
    addSwitchDialog.open()

  $scope.edit = (switchName) -> 
    switchData = currentGame.version.processes[switchName]
    editSwitchDialog = $dialog.dialog
      backdrop: true
      dialogFade: true
      backdropFade: true
      backdropClick: false
      templateUrl: 'game/switches/editSwitch.tpl.html'
      controller: 'EditSwitchDialogCtrl'
      resolve:
        # This object will be provided to the dialog as a dependency, and serves to communicate between the two
        switchIntermediary: ->
          {
            model:
              name: switchName
              paramDefs: switchData.paramDefs
              listActiveChildren: switchData.listActiveChildren
              handleSignals: switchData.handleSignals
            done: (model) ->
              # Handle rename case
              if model.name isnt switchName
                delete currentGame.version.processes[switchName]

              currentGame.version.processes[model.name] = 
                paramDefs: model.paramDefs
                listActiveChildren: model.listActiveChildren
                handleSignals: model.handleSignals

              editSwitchDialog.close()
            cancel: ->
              editSwitchDialog.close()
          }
    editSwitchDialog.open()

.controller 'EditSwitchDialogCtrl', ($scope, switchIntermediary) ->
  # Convert between "paramDef form" used in game serialization and "pin form" used in GUI
  toPins = (paramDefs) ->
    for paramName, paramDef of paramDefs
      name: paramName
      direction: paramDef?.direction || "in"
      default: paramDef?.default || "" 
  toParamDefs = (pins) ->
    paramDefs = {}
    for pin in pins
      paramDefs[pin.name] = 
        direction: pin.direction 
        default: if pin.direction is "in" then pin.default else null
    return paramDefs

  $scope.DIRECTIONS = ["in", "inout", "out"]
  $scope.name = switchIntermediary.model.name
  $scope.pins = toPins(switchIntermediary.model.paramDefs)
  $scope.listActiveChildrenText = switchIntermediary.model.listActiveChildren
  $scope.handleSignalsText = switchIntermediary.model.handleSignals

  $scope.addPin = -> $scope.pins.push({ name: "", direction: "in" })
  $scope.removePin = (index) -> $scope.arguments.splice(index, 1)

  # Reply with the new data
  $scope.done = -> switchIntermediary.done 
    name: $scope.name
    paramDefs: toParamDefs($scope.pins)
    listActiveChildren: $scope.listActiveChildrenText
    handleSignals: $scope.handleSignalsText
  $scope.cancel = -> switchIntermediary.cancel() 
