angular.module('gamEvolve.game.edit.header', [
  'gamEvolve.game.edit.header.time'
])

.controller 'GameInfoCtrl', ($scope, currentGame, gameTime) ->
  $scope.currentGame = currentGame

.controller 'MenuCtrl', ($scope, $state, $stateParams, $location, loggedUser, games, currentGame, loginDialog, aboutDialog, importExportDialog, editDescriptionDialog) ->
  $scope.user = loggedUser
  $scope.games = games
  $scope.currentGame = currentGame
  $scope.loginDialog = loginDialog
  $scope.aboutDialog = aboutDialog
  $scope.importExportDialog = importExportDialog
  $scope.loadGame = -> $state.transitionTo('game-list')
  $scope.gotoPlayScreen = -> $state.transitionTo('play', { gameId: $stateParams.gameId })
  $scope.editDescription = -> editDescriptionDialog.open()

  $scope.publishButtonDisabled = false
  $scope.isPublishButtonDisplayed = ->
    isGameLoaded() and loggedUser.isLoggedIn() and currentGame.info.ownerId is loggedUser.profile.id
  $scope.publishButtonClick = ->
    $scope.publishButtonDisabled = true
    games.publishCurrent().finally ->
      $scope.publishButtonDisabled = false

  isGameLoaded = ->
    currentGame.info and currentGame.version

  $scope.forkButtonDisabled = false
  $scope.isForkButtonDisplayed = ->
    isGameLoaded() and loggedUser.isLoggedIn()
  $scope.forkButtonClick = ->
    $scope.forkButtonDisabled = true
    games.forkCurrent().finally ->
      $scope.forkButtonDisabled = false