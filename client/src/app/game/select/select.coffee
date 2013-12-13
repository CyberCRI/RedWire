angular.module('gamEvolve.game.select', [
  'ui.bootstrap',
  'gamEvolve.model.games'
])

.factory 'gameSelectionDialog', ($dialog, currentGame) ->

    open: ->
      options =
        backdrop: true,
        dialogFade: true,
        backdropFade: true,
        templateUrl: 'game/select/select.tpl.html',
        controller: 'GameSelectionDialogCtrl',
      $dialog.dialog(options).open()


.controller 'GameSelectionDialogCtrl', ($scope, games, currentGame) ->

    # Registering services
    $scope.currentGame = currentGame

    $scope.games = []