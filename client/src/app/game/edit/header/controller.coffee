
angular.module('gamEvolve.game.edit.header', [
  'gamEvolve.game.edit.header.time'
])

.controller 'GameInfoCtrl', ($scope, currentGame, gameTime) ->
  $scope.currentGame = currentGame

.controller 'MenuCtrl', ($scope, $state, $stateParams, $location, loggedUser, games, currentGame, loginDialog, aboutDialog, importExportDialog) ->
  $scope.user = loggedUser
  $scope.games = games
  $scope.currentGame = currentGame
  $scope.loginDialog = loginDialog
  $scope.aboutDialog = aboutDialog
  $scope.importExportDialog = importExportDialog
  $scope.loadGame = -> $state.transitionTo('game-list')
  $scope.gotoPlayScreen = -> $state.transitionTo('play', { gameId: $stateParams.gameId })

  $scope.saveButtonDisabled = false
  lastSaveActionName = null
  $scope.getSaveButtonName = -> 
    if $scope.saveButtonDisabled then lastSaveActionName
    else games.getSaveAction().name
  $scope.getSaveButtonClasses = -> 
    if $scope.saveButtonDisabled then "font-icon-spin5 animate-spin"
    else games.getSaveAction().classes
  $scope.doSaveAction = ->
    lastSaveActionName = $scope.getSaveButtonName()
    $scope.saveButtonDisabled = true
    games.saveCurrent().finally ->
      $scope.saveButtonDisabled = false 

.controller 'LogoCtrl', ($scope, aboutDialog) ->
  $scope.aboutDialog = aboutDialog
