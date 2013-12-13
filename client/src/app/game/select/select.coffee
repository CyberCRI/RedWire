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
        title: 'Modal !!!'
      instance = $dialog.dialog(options)
      console.log instance.open
      instance.open()
#      $dialog.dialog(options).open()
#      modalInstance = $modal.open
#        templateUrl: 'game/select/select.tpl.html'
#        controller: 'GameSelectionDialogCtrl'
#        resolve:
#      modalInstance.result.then (selectedGame) -> currentGame.info = selectedGame



.controller 'GameSelectionDialogCtrl', ($scope, games, currentGame) ->

    # Registering services
    $scope.games = games
    $scope.currentGame = currentGame
