angular.module('gamEvolve.game.assets', [
  'ui.bootstrap'
  'omr.angularFileDnD'
  'xeditable'
])
.controller 'AssetsCtrl', ($scope, currentGame) ->
  # Get the actions object from the currentGame service, and keep it updated
  $scope.assets = []
  $scope.fileName = ""
  $scope.file = null

  # Transform assets to array so we can loop over it easier
  copyFromGameToScope = -> 
    if currentGame.version?.assets
      $scope.assets = ({ name: name, data: data } for name, data of currentGame.version.assets)

  # Bring currentGame into scope so we can watch it 
  $scope.currentGame = currentGame
  $scope.$watch("currentGame.localVersion", copyFromGameToScope, true)

  $scope.remove = (name) -> 
    if window.confirm("Are you sure you want to delete this asset?")
      delete currentGame.version.assets[name]
      currentGame.updateLocalVersion()

  $scope.$watch "file", ->
    if $scope.fileName is "" then return 

    currentGame.version?.assets[$scope.fileName] = $scope.file
    currentGame.updateLocalVersion()

    # Reset this so that the same filename dragged twice in a row will be taken into account
    $scope.fileName = ""  
    $scope.file = null
