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

.controller 'GameEditCtrl', ($scope, $filter, gameHistory, currentGame, boardConverter, gameTime) -> 
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
    newMemory = gameHistory.data.frames[gameTime.currentFrameNumber].memory
    if not _.isEqual($scope.memory, newMemory) 
      $scope.memory = newMemory
  $scope.$watch('gameHistoryMeta', onUpdateGameHistory, true)

  # Write back to gameHistory
  onUpdateMemory = ->
    if not gameHistory.data.frames[gameTime.currentFrameNumber]? then return 

    # If we are on the first frame, update the game memory
    if gameTime.currentFrameNumber == 0 
      if not _.isEqual($scope.memory, currentGame.version.memory) 
        currentGame.version.memory = $scope.memory
  $scope.$watch('memory', onUpdateMemory, true)

