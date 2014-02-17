
angular.module('gamEvolve.game.edit.header', [
  'gamEvolve.game.edit.header.time'
])

.controller 'GameInfoCtrl', ($scope, currentGame, gameTime) ->
    $scope.currentGame = currentGame
    $scope.gameTime = gameTime

.controller 'MenuCtrl', ($scope, $location, loggedUser, games, loginDialog, aboutDialog, importExportDialog) ->
    $scope.user = loggedUser
    $scope.games = games
    $scope.loginDialog = loginDialog
    $scope.aboutDialog = aboutDialog
    $scope.importExportDialog = importExportDialog
    $scope.loadGame = -> $location.path('/game/list')