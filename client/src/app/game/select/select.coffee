angular.module('gamEvolve.game.select', [
  'ui.bootstrap',
  'gamEvolve.model.games'
])

.factory 'gameSelectionDialog', ($dialog) ->

    current = null

    open: ->
      options =
        backdrop: true,
        dialogFade: true,
        backdropFade: true,
        templateUrl: 'game/select/select.tpl.html',
        controller: 'GameSelectionDialogCtrl',
      current = $dialog.dialog(options)
      current.open()

    close: ->
      current.close()


.controller 'GameSelectionDialogCtrl', ($scope, games, currentGame, gameSelectionDialog) ->

    # By default, games are ordered by Name
    $scope.orderedProperty = 'name'
    $scope.orderedDirection = false

    # Registering services
    $scope.currentGame = currentGame

    $scope.games = games.loadAll()

    $scope.select = (game) ->
      currentGame.info = game
      gameSelectionDialog.close()

    $scope.cancel = gameSelectionDialog.close