angular.module('gamEvolve.game.about', [
  'ui.bootstrap'
])

.factory 'aboutDialog', ($modal) ->
  current = null

  open: ->
    options =
      backdrop: true
      dialogFade: true
      backdrop: true
      templateUrl: 'game/about/aboutDialog.tpl.html'
      controller: 'AboutDialogCtrl'
    current = $modal.open(options)

  close: ->
    current.close()


.controller 'AboutDialogCtrl', ($scope, aboutDialog) ->
    $scope.ok = aboutDialog.close

