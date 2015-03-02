angular.module('gamEvolve.game.description', [
  'ui.bootstrap'
])

.factory 'editDescriptionDialog', ($modal, currentGame) ->
  dialog = null

  open: ->
    options =
      backdrop: true
      templateUrl: 'game/description/description.tpl.html'
      controller: 'EditDescriptionDialogCtrl'
      resolve: 
        # This object will be provided to the dialog as a dependency, and serves to communicate between the two
        liaison: ->
          {
            model: currentGame.version.description
            done: (newModel) ->
              currentGame.version.description = newModel
              currentGame.updateLocalVersion() # Increment local version of code

              dialog.close()
            cancel: ->
              dialog.close()
          }
    dialog = $modal.open(options)


.controller 'EditDescriptionDialogCtrl', ($scope, liaison) ->
  # Need to put input/output data under an object
  $scope.exchange = 
    description: liaison.model

  $scope.done = -> liaison.done($scope.exchange.description)
  $scope.cancel = -> liaison.cancel()