angular.module('gamEvolve.game.like', [])
.directive "likeButton", ->
  return {
    restrict: "E"
    scope: 
      gameId: "="
      likedData: "="
      buttonClasses: "="
    templateUrl: "game/like/like.tpl.html"
    controller: ($scope, games, loggedUser) ->
      # If the likedData is provided, use it. Otherwise query the backend
      if $scope.likedData 
        $scope.likedCount = $scope.likedData.likedCount 
        $scope.likedGame = $scope.likedData.likedGame 
      else
        $scope.likedCount = 0
        $scope.likedGame = false

        games.getLikeCount($scope.gameId).then (results) ->
          $scope.likedCount = results.likedCount
          $scope.likedGame = results.likedGame

      $scope.isDisabled = -> not loggedUser.isLoggedIn() or $scope.likedGame 

      updateLikeText = (likedCount) ->
        $scope.text = if likedCount then "#{likedCount} Likes" else "Like" 
      $scope.$watch("likedCount", updateLikeText)

      $scope.pickClasses = ->
        baseClasses = $scope.buttonClasses or [] 
        return baseClasses.concat(if $scope.likedGame then "btn-success" else "btn-default")

      $scope.onClick = ->
        if $scope.likedGame then return 
        if not loggedUser.isLoggedIn then 

        games.recordLike($scope.gameId).then ->
          $scope.likedCount++
          $scope.likedGame = true
  }