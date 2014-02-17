angular.module('gamEvolve.about', [
  'ui.bootstrap'
])

.factory 'aboutDialog', ($dialog) ->

    current = null

    open: ->
      options =
        backdrop: true
        dialogFade: true
        backdropFade: true
        templateUrl: 'about/aboutDialog.tpl.html'
        controller: 'AboutDialogCtrl'
      current = $dialog.dialog(options)
      current.open()

    close: ->
      current.close()


.controller 'AboutDialogCtrl', ($scope, aboutDialog) ->
    $scope.ok = aboutDialog.close

