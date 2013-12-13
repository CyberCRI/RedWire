angular.module('gamEvolve.game.time', [])
.controller('TimeCtrl', ($scope) ->
    $scope.currentFrame = 10
    $scope.totalFrames = 100
    $scope.isPlaying = false

    $scope.jumpToStart = -> $scope.currentFrame = 0
    $scope.jumpToEnd = -> $scope.currentFrame = $scope.totalFrames - 1
    $scope.stepForward = -> if $scope.currentFrame < $scope.totalFrames - 1 then $scope.currentFrame++
    $scope.stepBackward = -> if $scope.currentFrame > 0 then $scope.currentFrame--

    $scope.triggerPlay = -> $scope.isPlaying = !$scope.isPlaying
)
