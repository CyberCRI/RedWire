angular.module('gamEvolve.game.metrics', [
  'ui.bootstrap'
  'xeditable'
])

.controller 'MetricsConfCtrl', ($scope, currentGame) ->
  $scope.redMetricsConfig = 
    gameVersionId: ""
    host: ""

  copyFromGameToScope = -> 
    if not currentGame.version? then return
    $scope.redMetricsConfig = RW.cloneData(currentGame.version.redMetricsConfig)

  $scope.$watch((-> currentGame.localVersion), copyFromGameToScope)

  copyFromScopeToGame = -> 
    if not currentGame.version? then return
    if _.isEqual(currentGame.version.redMetricsConfig, $scope.redMetricsConfig) then return 
    currentGame.version.redMetricsConfig = RW.cloneData($scope.redMetricsConfig)
    currentGame.updateLocalVersion()
  $scope.$watch("redMetricsConfig", copyFromScopeToGame, true)

