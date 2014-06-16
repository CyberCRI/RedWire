angular.module('gamEvolve.game.toolbox.switches', [
  'ui.bootstrap',
])
.controller 'EditSwitchDialogCtrl', ($scope, liaison) ->
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
  $scope.exchange.listActiveChildrenText = liaison.model.listActiveChildren
  $scope.exchange.handleSignalsText = liaison.model.handleSignals

  $scope.addPin = -> $scope.exchange.pins.push({ name: "", direction: "in" })
  $scope.removePin = (index) -> $scope.exchange.pins.splice(index, 1)

  # Reply with the new data
  $scope.done = -> liaison.done 
    name: $scope.exchange.name
    pinDefs: toPinDefs($scope.exchange.pins)
    listActiveChildren: $scope.exchange.listActiveChildrenText
    handleSignals: $scope.exchange.handleSignalsText
  $scope.cancel = -> liaison.cancel() 
