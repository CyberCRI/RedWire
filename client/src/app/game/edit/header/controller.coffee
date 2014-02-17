
angular.module('gamEvolve.game.edit.header', [
  'gamEvolve.game.edit.header.time'
])

.controller 'GameInfoCtrl', ($scope, currentGame, gameTime) ->
    $scope.currentGame = currentGame
    $scope.gameTime = gameTime

.controller 'MenuCtrl', ($scope, loggedUser, games, loginDialog, gameSelectionDialog, importExportDialog) ->
    $scope.user = loggedUser
    $scope.games = games
    $scope.loginDialog = loginDialog
    $scope.gameSelectionDialog = gameSelectionDialog
    $scope.importExportDialog = importExportDialog