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

.controller 'GameListCtrl', ($scope, $q, games, loggedUser, users) ->
    $scope.isLoggedIn = -> loggedUser.isLoggedIn()

    makeSortQuery = (sortBy) ->
      switch sortBy
        when "latest" 
          lastUpdatedTime: -1
        when "mostLiked"
          likedCount: -1
        when "mostForks"
          forkCount: -1
        when "mostPlayed" 
          playCount: -1
        when "alphabetical" 
          name: 1
        when "userName" 
          ownerName: 1
        else
          throw new Error("Unknown sortBy", sortBy)

    wrapValueInPromise = (value) -> 
      deferred = $q.defer()
      deferred.resolve(value)
      return deferred.promise

    $scope.countAllGames = -> games.countGames()
    $scope.getPageOfAllGames = (pageNumber, gamesPerPage, sortBy) -> games.getPageOfGames pageNumber, gamesPerPage,
      $sort: makeSortQuery(sortBy)

    $scope.countMyGames = -> games.countGames
      ownerId: loggedUser.profile.id 
    $scope.getPageOfMyGames = (pageNumber, gamesPerPage, sortBy) -> games.getPageOfGames pageNumber, gamesPerPage, 
      ownerId: loggedUser.profile.id 
      $sort: makeSortQuery(sortBy)

    # There are always 3 recommendations, with no paging
    $scope.countRecommendations = -> wrapValueInPromise(3)
    $scope.getPageOfRecommendations = (pageNumber, gamesPerPage, sortBy) -> games.getRecommendations()
