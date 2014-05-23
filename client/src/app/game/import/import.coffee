angular.module('gamEvolve.game.import', [
  'ui.bootstrap'
])

.factory 'importExportDialog', ($modal, gameConverter, currentGame) ->
  dialog = null

  open: ->
    options =
      backdrop: true
      dialogFade: true
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
  $scope.gameCode = liaison.model

  $scope.done = -> liaison.done($scope.gameCode)
  $scope.cancel = -> liaison.cancel()