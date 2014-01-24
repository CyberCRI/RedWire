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
  $scope.model = {}
  $scope.currentGame = currentGame;
  $scope.board = {}
  $scope.gameHistoryMeta = gameHistory.meta # In order to watch it
  $scope.$watch('currentGame.version.layout',
    ((json) -> if json
      $scope.board = boardConverter.convert(json)),
    false)

  $scope.$watch('board', (board) -> console.log board)

  # Update from gameHistory
  onUpdateGameHistory = ->
    if not gameHistory.data.frames[gameTime.currentFrameNumber]? then return 

    newModel = gameHistory.data.frames[gameTime.currentFrameNumber].model
    if not _.isEqual($scope.model, newModel) 
      $scope.model = newModel
  $scope.$watch('gameHistoryMeta', onUpdateGameHistory, true)

  # Write back to gameHistory
  onUpdateModel = ->
    if not gameHistory.data.frames[gameTime.currentFrameNumber]? then return 

    # If we are on the first frame, update the game model
    if gameTime.currentFrameNumber == 0 
      if not _.isEqual($scope.model, currentGame.version.model) 
        currentGame.version.model = $scope.model
  $scope.$watch('model', onUpdateModel, true)

