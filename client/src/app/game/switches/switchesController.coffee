angular.module('gamEvolve.game.switches', [
  'ui.bootstrap',
])
.controller 'SwitchesListCtrl', ($scope, $dialog, currentGame) ->
  # Get the switches object from the currentGame service, and keep it updated
  $scope.switches = {}
  $scope.switchNames = []

  # Bring currentGame into scope so we can watch it 
  updateSwitches = ->
    if currentGame.version?.switches?
      $scope.switches = currentGame.version.switches
      $scope.switchNames = _.keys(currentGame.version.switches)
  $scope.currentGame = currentGame
  $scope.$watch('currentGame', updateSwitches, true)

  $scope.remove = (name) ->
    delete currentGame.version.switches[name]

  $scope.add = () ->
    addSwitchDialog = $dialog.dialog
      backdrop: true
      dialogFade: true
      backdropFade: true
      backdropClick: false
      templateUrl: 'game/switches/editSwitch.tpl.html'
      dialogClass: "large-modal"
      controller: 'EditSwitchDialogCtrl'
      resolve:
        # This object will be provided to the dialog as a dependency, and serves to communicate between the two
        switchIntermediary: ->
          {
            model:
              name: ""
              pinDefs: {}
              listActiveChildren: ""
              handleSignals: ""
            done: (model) ->
              currentGame.version.switches[model.name] = 
                pinDefs: model.pinDefs
                listActiveChildren: model.listActiveChildren
                handleSignals: model.handleSignals

              addSwitchDialog.close()
            cancel: ->
              addSwitchDialog.close()
          }
    addSwitchDialog.open()

  $scope.edit = (switchName) -> 
    switchData = currentGame.version.switches[switchName]
    editSwitchDialog = $dialog.dialog
      backdrop: true
      dialogFade: true
      backdropFade: true
      backdropClick: false
      templateUrl: 'game/switches/editSwitch.tpl.html'
      dialogClass: "large-modal"
      controller: 'EditSwitchDialogCtrl'
      resolve:
        # This object will be provided to the dialog as a dependency, and serves to communicate between the two
        switchIntermediary: ->
          {
            model:
              name: switchName
              pinDefs: switchData.pinDefs
              listActiveChildren: switchData.listActiveChildren
              handleSignals: switchData.handleSignals
            done: (model) ->
              # Handle rename case
              if model.name isnt switchName
                delete currentGame.version.switches[switchName]

              currentGame.version.switches[model.name] = 
                pinDefs: model.pinDefs
                listActiveChildren: model.listActiveChildren
                handleSignals: model.handleSignals

              editSwitchDialog.close()
            cancel: ->
              editSwitchDialog.close()
          }
    editSwitchDialog.open()

.controller 'EditSwitchDialogCtrl', ($scope, switchIntermediary) ->
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
  $scope.name = switchIntermediary.model.name
  $scope.pins = toPins(switchIntermediary.model.pinDefs)
  $scope.listActiveChildrenText = switchIntermediary.model.listActiveChildren
  $scope.handleSignalsText = switchIntermediary.model.handleSignals

  $scope.addPin = -> $scope.pins.push({ name: "", direction: "in" })
  $scope.removePin = (index) -> $scope.pins.splice(index, 1)

  # Reply with the new data
  $scope.done = -> switchIntermediary.done 
    name: $scope.name
    pinDefs: toPinDefs($scope.pins)
    listActiveChildren: $scope.listActiveChildrenText
    handleSignals: $scope.handleSignalsText
  $scope.cancel = -> switchIntermediary.cancel() 
