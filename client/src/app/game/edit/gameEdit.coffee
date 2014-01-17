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

.controller 'GameEditCtrl', ($scope, $filter, gameHistory, currentGame, boardConverter) ->
  $scope.currentGame = currentGame;
  $scope.model = {}
  $scope.gameHistory = gameHistory # In order to watch it
  $scope.board = {}
  $scope.$watch('currentGame.version.layout',
    ((json) -> if json
      $scope.board = boardConverter.convert(json)),
    false)

  # Update from gameHistory
  onUpdateGameHistory = ->
    if not gameHistory.frames[gameHistory.currentFrameNumber]? then return 

    newModel = gameHistory.frames[gameHistory.currentFrameNumber].model
    if not _.isEqual($scope.model, newModel) 
      $scope.model = newModel
  $scope.$watch('gameHistory', onUpdateGameHistory, true)

  # Write back to gameHistory
  onUpdateModel = ->
    if not gameHistory.frames[gameHistory.currentFrameNumber]? then return 

    # If we are on the first frame, update the game model
    if gameHistory.currentFrameNumber == 0 
      if not _.isEqual($scope.model, currentGame.version.model) 
        currentGame.version.model = $scope.model
  $scope.$watch('model', onUpdateModel, true)

