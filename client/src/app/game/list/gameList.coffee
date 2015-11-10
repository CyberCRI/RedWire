angular.module('gamEvolve.game.list', ["ui.bootstrap.pagination"])

.config ($stateProvider) ->
    $stateProvider.state 'game-list',
      url: '/game/list?&page'
      views:
        "main":
          controller: 'GameListCtrl'
          templateUrl: 'game/list/gameList.tpl.html'
      data:
        pageTitle: 'List Games'

.controller 'GameListCtrl', ($scope, games, loggedUser, ChangedLoginEvent, users) ->
    # Sort games by reverse chronological order
    timeSorter = (game) -> -1 * new Date(game.lastUpdatedTime).valueOf()

    # Sort games by likes
    likeSorter = (game) -> return -1 * game.likedData.likedCount

    $scope.gamesPerPage = 3 * 3

    $scope.allGames = []
    $scope.recommendations = []
    $scope.myGames = []
    $scope.page = 1

    # Keep track of last page so not to repeat the same request 
    lastRequestedPage = null

    loadAllGamesPage = ->
      # Don't bother repeating the same request
      if lastRequestedPage == $scope.page then return
      lastRequestedPage = $scope.page

      games.loadPage($scope.page, $scope.gamesPerPage).then (allGames) ->
        $scope.allGames = allGames      
    $scope.$watch("page", loadAllGamesPage)

    loadGames = ->
      makeRequests = ->
        if loggedUser.isLoggedIn() 
          games.getMyGames().then (myGames) ->
            $scope.myGames = _.sortBy(myGames, timeSorter)

        loadAllGamesPage()

        games.getRecommendations().then (recommendations) -> $scope.gameRecommendations = recommendations

      # First try to log user in before getting game lists
      if loggedUser.isLoggedIn() then makeRequests()
      else users.restoreSession().then(-> makeRequests())

    loadGames()
    unsubscribeChangedLoginEvent = ChangedLoginEvent.listen(loadGames)

    $scope.$on("destroy", unsubscribeChangedLoginEvent)
