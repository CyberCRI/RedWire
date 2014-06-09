
angular.module('gamEvolve.game.list', [])

.config ($stateProvider) ->
    $stateProvider.state 'game-list',
      url: '/game/list'
      views:
        "main":
          controller: 'GameListCtrl'
          templateUrl: 'game/list/gameList.tpl.html'
      data:
        pageTitle: 'List Games'

.controller 'GameListCtrl', ($scope, games, $state) ->
    $scope.games = []

    games.loadAll().then (gamesList) -> $scope.games = gamesList

    $scope.remix = (gameId) -> $state.transitionTo('game-edit', {gameId: gameId})
    $scope.play = (gameId) -> $state.transitionTo('play', {gameId: gameId})
