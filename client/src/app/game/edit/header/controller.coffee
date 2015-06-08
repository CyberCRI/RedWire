angular.module('gamEvolve.game.edit.header', [
  'gamEvolve.game.edit.header.time','ui.bootstrap'
])

.controller 'GameInfoCtrl', ($scope, currentGame, gameTime) ->
  $scope.currentGame = currentGame

.controller 'MenuCtrl', ($scope, $state, $stateParams, $location, $window, loggedUser, games, currentGame, loginDialog, aboutDialog, importExportDialog, editDescriptionDialog) ->
  $scope.user = loggedUser
  $scope.games = games
  $scope.currentGame = currentGame
  $scope.loginDialog = loginDialog
  $scope.aboutDialog = aboutDialog
  $scope.importExportDialog = importExportDialog
  $scope.loadGame = -> $state.transitionTo('game-list')
  $scope.gotoPlayScreen = -> $state.transitionTo('play', { gameId: $stateParams.gameId })
  $scope.editDescription = -> editDescriptionDialog.open()
  $scope.status = 
    isOpen: false

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

  deleteInProgress = false
  $scope.isDeleteButtonDisplayed = ->
    isGameLoaded() and loggedUser.isLoggedIn() and currentGame.info.ownerId is loggedUser.profile.id and not deleteInProgress
  $scope.deleteButtonClick = ->
    if not $window.confirm """WARNING: If you delete the game then you can never go back and play it.

             Are you sure?"""
      return 

    deleteInProgress = true
    games.deleteCurrent().finally ->
      deleteInProgress = false
      $state.transitionTo('game-list')

  $scope.helpButton = ->
    $window.open('http://github.com/CyberCRI/RedWire/wiki/Tutorials','_blank')
    return