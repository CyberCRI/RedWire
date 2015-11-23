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

    $scope.countRecommendations = -> games.countRecommendations()
    $scope.getPageOfRecommendations = (pageNumber, gamesPerPage, sortBy) -> games.getRecommendations()

    # From http://stackoverflow.com/questions/3446170/escape-string-for-use-in-javascript-regex
    escapeRegExp = (str) -> str.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&");

    # When the search text changes, make new functions to handle the search
    $scope.searchText = ""
    changeSearchText = ->
      if not $scope.searchText then return 

      queryBase = 
        $or: [{ name: { $regex: escapeRegExp($scope.searchText), $options: "i" } }, { ownerName: { $regex: escapeRegExp($scope.searchText), $options: "i" } }]

      $scope.countSearchedGames = -> games.countGames(queryBase)
      $scope.getPageOfSearchedGames = (pageNumber, gamesPerPage, sortBy) -> games.getPageOfGames pageNumber, gamesPerPage, _.extend {}, queryBase,
        $sort: makeSortQuery(sortBy)

    $scope.$watch("searchText", changeSearchText)

    $scope.clearSearchText = -> $scope.searchText = ""
