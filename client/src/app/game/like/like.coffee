angular.module('gamEvolve.game.like', [])
.directive "likeButton", ->
  return {
    restrict: "E"
    scope: 
      gameId: "="
    templateUrl: "game/like/like.tpl.html"
    controller: ($scope, games) ->
      $scope.likedCount = 0

      updateLikeText = (likedCount) ->
        if likedCount then $scope.text = "#{likedCount} likes"
      $scope.$watch("likedCount", updateLikeText)

      $scope.doesLike = false

      games.getLikeCount($scope.gameId).then (results) ->
        $scope.likedCount = results.likedCount
        # TODO: update $scope.doesLike

      $scope.onClick = ->
        games.recordLike($scope.gameId).then ->
          $scope.likedCount++
          $scope.doesLike = true
  }