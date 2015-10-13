angular.module('gamEvolve.game.edit.header', [
  'gamEvolve.game.edit.header.time','gamEvolve.game.edit.header.volume','ui.bootstrap'
])

.controller 'GameInfoCtrl', ($scope, currentGame, gameTime) ->
  $scope.name = null
  $scope.versionNumber = null
  $scope.creator = null

  copyFromGameToScope = -> 
    if not currentGame.version? then return
    
    $scope.name = currentGame.info.name
    $scope.versionNumber = currentGame.version.versionNumber
    $scope.creator = currentGame.creator

  $scope.$watch((-> currentGame.localVersion), copyFromGameToScope, true)
  $scope.$watch((-> currentGame.version), copyFromGameToScope, true)

  copyFromScopeToGame = -> 
    if $scope.name == null then return 

    currentGame.info.name = $scope.name

    currentGame.updateLocalVersion()

  $scope.$watch("name", copyFromScopeToGame, true)


.controller 'MenuCtrl', ($scope, $state, $stateParams, $location, $window, loggedUser, games, currentGame, loginDialog, aboutDialog, importExportDialog, editDescriptionDialog, showDescriptionDialog) ->
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

  $scope.publishInProgress = false
  $scope.isPublishButtonDisplayed = ->
    isGameLoaded() and loggedUser.isLoggedIn() and (currentGame.info.ownerId is loggedUser.profile.id or loggedUser.profile.isAdmin)
  $scope.publishButtonClick = ->
    $scope.publishInProgress = true
    games.publishCurrent().finally ->
      $scope.publishInProgress = false

  $scope.isPublishButtonDisabled = -> $scope.publishInProgress or not currentGame.hasUnpublishedChanges

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
    isGameLoaded() and loggedUser.isLoggedIn() and (currentGame.info.ownerId is loggedUser.profile.id or loggedUser.profile.isAdmin) and not deleteInProgress
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

  $scope.showScreenshots = -> showDescriptionDialog.open()
