angular.module('gamEvolve.game.play', ["ngSanitize"])

.config ($stateProvider) ->
  $stateProvider.state 'play',
    url: '/game/:gameId/play'
    views:
      "main":
        controller: 'PlayCtrl'
        templateUrl: 'game/play/play.tpl.html'
    data:
      pageTitle: 'Play Game'

.controller 'PlayCtrl', ($scope, $state, games, gameTime, gameHistory, currentGame, $stateParams) ->
  $scope.isLoading = true

  onUpdateGameHistory = -> 
    if gameHistory.meta.version is 1 
      gameTime.isPlaying = true
      $scope.isLoading = false

  # Bring gameHistory into scope so we can watch it
  $scope.gameHistoryMeta = gameHistory.meta
  $scope.$watch("gameHistoryMeta", onUpdateGameHistory, true)

  $scope.remix = -> $state.transitionTo('game-edit', { gameId: $stateParams.gameId }) 
  $scope.listGames = -> $state.transitionTo('game-list') 

  games.loadFromId($stateParams.gameId)
  games.recordPlay($stateParams.gameId)

  $scope.title = ""
  $scope.author = ""
  $scope.description = ""
  onUpdateCurrentGame = -> 
    $scope.title = currentGame.info?.name
    $scope.author = currentGame.creator
    $scope.description = currentGame.version?.description

  $scope.currentGame = currentGame
  $scope.$watch("currentGame.localVersion", onUpdateCurrentGame, true)

