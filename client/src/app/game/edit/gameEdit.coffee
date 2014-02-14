angular.module('gamEvolve.game.edit', ['flexyLayout'])

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
  $scope.currentGame = currentGame;
  $scope.board = {}

  # When the board changes, update in scope
  updateBoard = -> 
    if currentGame.version?.board
      $scope.board = boardConverter.convert(currentGame.version.board)
  $scope.$watch('currentGame.version.board', updateBoard, true)

