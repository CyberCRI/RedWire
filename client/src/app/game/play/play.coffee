angular.module('gamEvolve.game.play', [])

.config ($stateProvider) ->
  $stateProvider.state 'play',
    url: '/game/:gameId/play'
    views:
      "main":
        controller: 'PlayCtrl'
        templateUrl: 'game/play/play.tpl.html'
    data:
      pageTitle: 'Play Game'

.controller 'PlayCtrl', ($scope, games, gameTime, gameHistory, $stateParams) ->
  onUpdateGameHistory = -> 
    if gameHistory.meta.version is 1 then gameTime.isPlaying = true

  # Bring gameHistory into scope so we can watch it
  $scope.gameHistoryMeta = gameHistory.meta
  $scope.$watch("gameHistoryMeta", onUpdateGameHistory, true)

  games.loadFromId($stateParams.gameId)
