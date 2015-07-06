angular.module('gamEvolve.game.boardLabel', [
  'gamEvolve.model.chips'
])

.directive 'boardLabel', ->
  return {
    templateUrl: 'game/board/boardLabel.tpl.html'
    controller: 'BoardLabelCtrl'
    restrict: 'E'
    scope:
      node: '='
  }

.controller 'BoardLabelCtrl', ($scope, chips, boardNodes, gameHistory, gameTime, circuits) ->
  $scope.chips = chips

  $scope.getChipDescription = (chip) ->
    switch chips.getType(chip)
      when "switch" then chip.switch
      when "processor" then chip.processor
      when "emitter" then "Emitter"
      when "splitter" then "Splitter"
      when "circuit" then "Circuit"
      when "pipe" then "Pipe"
      else "Unknown Type"

  $scope.getChildName = (chip) -> 
    if not chip? then return null
  
    if chip.name? then JSON.stringify(chip.name) else ""

  $scope.getActivationStyle = (chip) ->
    if not circuits.currentCircuitMeta.id? or gameHistory.data.frames.length == 0 then return "label-default"

    # Get the current data for the circuit instance
    activeChipPaths = gameHistory.data.frames[gameTime.currentFrameNumber].activeChipPaths[circuits.currentCircuitMeta.id]
    chipPath = boardNodes.getChipPath(chip) 
    if not chipPath? then return "label-default"

    return if RW.contains(activeChipPaths, chipPath) then "label-success" else "label-default"
