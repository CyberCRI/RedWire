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

.controller 'BoardLabelCtrl', ($scope, chips) ->

  $scope.chips = chips

  $scope.getChipDescription = (chip) ->
    switch chips.getType(chip)
      when "switch" then chip.switch
      when "processor" then chip.processor
      when "emitter" then "Emitter"
      when "splitter" then "Splitter"
      when "circuit" then "Circuit"
      else "Unknown Type"
