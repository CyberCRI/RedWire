
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
    # Sort games by reverse chronological order
    sortGames = (games) -> return _.sortBy games, (game) -> 
      return -1 * new Date(game.lastUpdatedTime).valueOf()

    allGames = []
    recommendations = []

    games.loadAll().then (gamesList) -> $scope.games = sortGames(gamesList)

    getRecommendations = ->
      games.getRecommendations().then (recommendations) -> $scope.gameRecommendations = recommendations

    getRecommendations()
    ChangedLoginEvent.listen(getRecommendations)
