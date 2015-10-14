angular.module('gamEvolve.game.screenshots', [
  'ui.bootstrap'
])

.factory 'showDescriptionDialog', ($modal, currentGame) ->
  dialog = null

  open: ->
    options =
      backdrop: true
      templateUrl: 'game/screenshots/screenshots.tpl.html'
      controller: 'EditScreenshotsDialogCtrl'
      resolve: 
        # This object will be provided to the dialog as a dependency, and serves to communicate between the two
        liaison: ->
          {
            model: {}
            done: ->
              dialog.close()
          }
    dialog = $modal.open(options)


.controller 'EditScreenshotsDialogCtrl', ($scope, liaison, currentGame, gameTime, RequestScreenshotEvent, RequestRecordAnimationEvent) ->
  $scope.currentGameVersion = currentGame.version
  $scope.gameTime = gameTime

  $scope.takeScreenshot = -> RequestScreenshotEvent.send()

  $scope.recordAnimation = -> RequestRecordAnimationEvent.send()

  $scope.done = -> liaison.done()
