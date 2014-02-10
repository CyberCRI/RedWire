# Modifies the object by taking out the "$$hashKey" property put in by AngularJS
filterOutHashKey = (obj) ->
  if "$$hashKey" of obj then delete obj["$$hashKey"]
  for key, value of obj
    if _.isObject(value) then filterOutHashKey(value)
  return obj

angular.module('gamEvolve.game.edit', ['flexyLayout', 'JSONedit'])

.config ($stateProvider) ->
  $stateProvider.state 'game.edit', 
    url: '/:gameId/edit'
    views: 
      "game.main": 
        controller: 'GameEditCtrl'
        templateUrl: 'game/edit/gameEdit.tpl.html'
    data: 
      pageTitle: 'Edit Game'

.controller 'GameEditCtrl', ($scope, $stateParams, games, $filter, gameHistory, currentGame, boardConverter, gameTime) ->
  games.loadFromId $stateParams.gameId
  $scope.memory = {}
  $scope.currentGame = currentGame;
  $scope.board = {}
  $scope.gameHistoryMeta = gameHistory.meta # In order to watch it
  $scope.gameTime = gameTime

  # When the board changes, update in scope
  updateBoard = -> 
    if currentGame.version?.board
      $scope.board = boardConverter.convert(currentGame.version.board)
  $scope.$watch('currentGame.version.board', updateBoard, true)

  # Update from gameHistory
  onUpdateGameHistory = ->
    if not gameHistory.data.frames[gameTime.currentFrameNumber]? then return 
    # Clone is necessary to avoid AngularJS adding in $$hashKey properties
    $scope.memory = GE.cloneData(gameHistory.data.frames[gameTime.currentFrameNumber].memory)
  $scope.$watch('gameHistoryMeta', onUpdateGameHistory, true)

  # Write back to gameHistory
  onUpdateMemory = ->
    if not gameHistory.data.frames[gameTime.currentFrameNumber]? then return 

    # If we are on the first frame, update the game memory
    if gameTime.currentFrameNumber == 0 
      newMemory = GE.cloneData($scope.memory)
      currentGame.version.memory = filterOutHashKey(newMemory)
  $scope.$watch('memory', onUpdateMemory, true)

