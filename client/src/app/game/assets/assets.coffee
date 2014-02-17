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
  $scope.$watch('currentGame', copyFromGameToScope, true)

  # Transform assets back to object
  copyFromScopeToGames = -> 
    if currentGame.version?.assets
      currentGame.version.assets = _.object( ([asset.name, asset.data] for asset in $scope.assets) )
  $scope.$watch('assets', copyFromScopeToGames, true)

  $scope.remove = (name) -> delete currentGame.version.assets[name]

  $scope.$watch "file", ->
    currentGame.version?.assets[$scope.fileName] = $scope.file
    console.log("added file", $scope.fileName, $scope.file)
