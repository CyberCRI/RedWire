
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

  $scope.getSaveButtonName = -> games.getSaveAction().name
  $scope.getSaveButtonClasses = -> 
    if $scope.saveButtonDisabled then "font-icon-spin5 animate-spin" 
    else games.getSaveAction().classes
  $scope.doSaveAction = ->
    $scope.saveButtonDisabled = true 
    games.saveCurrent().finally ->
      $scope.saveButtonDisabled = false 

  $scope.saveButtonDisabled = false
  #updateOperationInProgress = -> $scope.saveButtonDisabled = games.updateOperationInProgress
  #$scope.$watch("games.operationInProgress", updateOperationInProgress)

.controller 'LogoCtrl', ($scope, aboutDialog) ->
  $scope.aboutDialog = aboutDialog
