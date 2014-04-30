# Modifies the object by taking out the "$$hashKey" property put in by AngularJS
filterOutHashKey = (obj) ->
  if "$$hashKey" of obj then delete obj["$$hashKey"]
  for key, value of obj
    if _.isObject(value) then filterOutHashKey(value)
  return obj


angular.module('gamEvolve.game.edit', [
  'flexyLayout'
  'gamEvolve.game.memory'
  'gamEvolve.game.edit.header'
])


.config ($stateProvider) ->
  $stateProvider.state 'game-edit',
    url: '/game/:gameId/edit'
    views: 
      "main":
        controller: 'GameEditCtrl'
        templateUrl: 'game/edit/gameEdit.tpl.html'
    data: 
      pageTitle: 'Edit Game'


.controller 'GameEditCtrl', ($scope, $stateParams, games, $filter, gameHistory, currentGame, boardConverter, gameTime) ->
  games.loadFromId $stateParams.gameId
  $scope.currentGame = currentGame;
  $scope.board = {}

  # When the board changes, update in scope
  updateBoard = -> 
    if currentGame.version?.board
      $scope.board = boardConverter.convert(currentGame.version.board)
  $scope.$watch('currentGame', updateBoard, true)


.controller 'BasicChipLibraryCtrl', ($scope) ->

  $scope.newSplitter = ->
    splitter:
      from: ''
      bindTo: ''
      index: ''