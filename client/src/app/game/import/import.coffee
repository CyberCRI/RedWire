angular.module('gamEvolve.game.import', [
  'ui.bootstrap'
])

.factory 'importExportDialog', ($modal, gameConverter, currentGame) ->
  dialog = null

  open: ->
    options =
      backdrop: true
      templateUrl: 'game/import/import.tpl.html'
      controller: 'ImportExportDialogCtrl'
      resolve: 
        # This object will be provided to the dialog as a dependency, and serves to communicate between the two
        liaison: ->
          {
            model: gameConverter.convertGameToJson(currentGame)
            done: (newModel) ->
              newGame = gameConverter.convertGameFromJson(newModel)

              # Don't lose existing meta-info, but change the game code completely
              _.extend(currentGame.info, newGame.info)
              # TODO: check that the import doesn't overwrite internal properties (versionNumber, id, etc.)
              _.extend(currentGame.version, newGame.version)
              currentGame.updateLocalVersion() # Increment local version of code

              dialog.close()
            cancel: ->
              dialog.close()
          }
    dialog = $modal.open(options)


.controller 'ImportExportDialogCtrl', ($scope, liaison) ->
  # Need to put input/output data under an object
  $scope.exchange = 
    gameCode: liaison.model

  $scope.done = -> liaison.done($scope.exchange.gameCode)
  $scope.cancel = -> liaison.cancel()