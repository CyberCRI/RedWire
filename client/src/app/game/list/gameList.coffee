
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
    timeSorter = (game) -> -1 * new Date(game.lastUpdatedTime).valueOf()

    # Sort games by likes
    likeSorter = (game) -> return -1 * game.likedData.likedCount

    allGames = []
    recommendations = []

    games.loadAll().then (gamesList) -> $scope.games = _.sortBy(gamesList, likeSorter)

    getRecommendations = ->
      games.getRecommendations().then (recommendations) -> $scope.gameRecommendations = recommendations

    getRecommendations()
    ChangedLoginEvent.listen(getRecommendations)
