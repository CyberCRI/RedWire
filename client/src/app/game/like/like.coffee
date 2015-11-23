angular.module('gamEvolve.game.like', [])
.directive "likeButton", ->
  return {
    restrict: "E"
    scope: 
      gameId: "="
      likedCount: "=?"
      buttonClasses: "=?"
    templateUrl: "game/like/like.tpl.html"
    controller: ($scope, games, loggedUser, ChangedLoginEvent) ->
      # If the data about likes is provided, use it. Otherwise query the backend
      if not $scope.likedCount? 
        $scope.likedCount = 0
        games.getLikedCount($scope.gameId).then (results) ->
          $scope.likedCount = results.likedCount

      # Check if the user already liked the game
      $scope.likedGame = -> loggedUser.isLoggedIn() and _.contains(loggedUser.profile.likedGames, $scope.gameId)

      $scope.isDisabled = -> not loggedUser.isLoggedIn() or $scope.likedGame()

      updateLikeText = (likedCount) ->
        $scope.text = if likedCount then "#{likedCount} Likes" else "Like" 
      $scope.$watch("likedCount", updateLikeText)

      $scope.pickClasses = ->
        baseClasses = $scope.buttonClasses or [] 
        return baseClasses.concat(if $scope.likedGame() then "btn-success" else "btn-default")

      $scope.onClick = ->
        if $scope.likedGame() then return 
        if not loggedUser.isLoggedIn then 

        games.recordLike($scope.gameId).then ->
          $scope.likedCount++
          loggedUser.profile.likedGames.push($scope.gameId)
  }