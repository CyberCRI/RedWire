angular.module('gamEvolve.game.like', [])
.directive "likeButton", ->
  return {
    restrict: "E"
    scope: 
      gameId: "="
    templateUrl: "game/like/like.tpl.html"
    controller: ($scope, games, loggedUser) ->
      $scope.likedCount = 0
      $scope.isLoggedIn = -> loggedUser.isLoggedIn

      updateLikeText = (likedCount) ->
        $scope.text = if likedCount then "#{likedCount} Likes" else "Like" 
      $scope.$watch("likedCount", updateLikeText)

      $scope.doesLike = false

      games.getLikeCount($scope.gameId).then (results) ->
        $scope.likedCount = results.likedCount
        $scope.doesLike = results.likedGame

      $scope.onClick = ->
        if $scope.doesLike then return 

        games.recordLike($scope.gameId).then ->
          $scope.likedCount++
          $scope.doesLike = true
  }