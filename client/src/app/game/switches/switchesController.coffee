angular.module('gamEvolve.game.switches', [
  'ui.bootstrap',
])
.controller 'SwitchesListCtrl', ($scope, $modal, currentGame, SwitchRenamedEvent) ->
  # Get the switches object from the currentGame service, and keep it updated
  $scope.switches = {}
  $scope.switchNames = []

  # Bring currentGame into scope so we can watch it 
  updateSwitches = ->
    if currentGame.version?.switches?
      $scope.switches = currentGame.version.switches
      $scope.switchNames = _.keys(currentGame.version.switches)
  $scope.currentGame = currentGame
  $scope.$watch("currentGame.localVersion", updateSwitches, true)

  $scope.newSwitch = (switchName) ->
    switch: switchName
    pins:
      in: {}
      out: {}

  $scope.remove = (name) ->
    if window.confirm("Are you sure you want to delete this switch?")
      delete currentGame.version.switches[name]
      currentGame.updateLocalVersion()

  $scope.add = () ->
    addSwitchDialog = $modal.open
      backdrop: "static"
      templateUrl: 'game/switches/editSwitch.tpl.html'
      size: "lg"
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
              currentGame.updateLocalVersion()

              addSwitchDialog.close()
            cancel: ->
              addSwitchDialog.close()
          }

  $scope.edit = (switchName) -> 
    switchData = currentGame.version.switches[switchName]
    editSwitchDialog = $modal.open
      backdrop: "static"
      templateUrl: 'game/switches/editSwitch.tpl.html'
      size: "lg"
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
                SwitchRenamedEvent.send
                  oldName: switchName
                  newName: model.name
                delete currentGame.version.switches[switchName]

              currentGame.version.switches[model.name] = 
                pinDefs: model.pinDefs
                listActiveChildren: model.listActiveChildren
                handleSignals: model.handleSignals

              currentGame.updateLocalVersion()
              editSwitchDialog.close()
            cancel: ->
              editSwitchDialog.close()
          }

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

  # Need to put 2-way data binding under an object
  $scope.exchange = {}
  $scope.exchange.name = switchIntermediary.model.name
  $scope.exchange.pins = toPins(switchIntermediary.model.pinDefs)
  $scope.exchange.listActiveChildrenText = switchIntermediary.model.listActiveChildren
  $scope.exchange.handleSignalsText = switchIntermediary.model.handleSignals

  $scope.addPin = -> $scope.exchange.pins.push({ name: "", direction: "in" })
  $scope.removePin = (index) -> $scope.exchange.pins.splice(index, 1)

  # Reply with the new data
  $scope.done = -> switchIntermediary.done 
    name: $scope.exchange.name
    pinDefs: toPinDefs($scope.exchange.pins)
    listActiveChildren: $scope.exchange.listActiveChildrenText
    handleSignals: $scope.exchange.handleSignalsText
  $scope.cancel = -> switchIntermediary.cancel() 
