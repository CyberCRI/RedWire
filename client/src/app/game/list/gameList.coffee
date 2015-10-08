
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

.controller 'GameListCtrl', ($scope, games, $state, ChangedLoginEvent) ->
    $scope.games = []

    $scope.formatDate = (date) -> moment(date).fromNow()

    games.loadAll().then (gamesList) -> $scope.games = gamesList

    getRecommendations = ->
      games.getRecommendations().then (recommendations) -> $scope.gameRecommendations = recommendations

    getRecommendations()
    ChangedLoginEvent.listen(getRecommendations)

    $scope.remix = (gameId) -> $state.transitionTo('game-edit', {gameId: gameId})
    $scope.play = (gameId) -> $state.transitionTo('play', {gameId: gameId})
