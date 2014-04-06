
angular.module('gamEvolve.game.edit.header', [
  'gamEvolve.game.edit.header.time'
])

.controller 'GameInfoCtrl', ($scope, currentGame, gameTime) ->
    $scope.currentGame = currentGame
    $scope.gameTime = gameTime

.controller 'MenuCtrl', ($scope, $state, $stateParams, $location, loggedUser, games, currentGame, loginDialog, aboutDialog, importExportDialog) ->
    $scope.user = loggedUser
    $scope.games = games
    $scope.currentGame = currentGame
    $scope.loginDialog = loginDialog
    $scope.aboutDialog = aboutDialog
    $scope.importExportDialog = importExportDialog
    $scope.loadGame = -> $location.path('/game/list')
    $scope.gotoPlayScreen = -> $state.transitionTo('play', { gameId: $stateParams.gameId })

.controller 'LogoCtrl', ($scope, aboutDialog) ->
    $scope.aboutDialog = aboutDialog
