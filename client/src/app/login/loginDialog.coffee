angular.module('gamEvolve.login', [
  'ui.bootstrap',
  'gamEvolve.model.users'
])

.factory 'loginDialog', ($dialog) ->

    current = null

    open: ->
      options =
        backdrop: true,
        dialogFade: true,
        backdropFade: true,
        templateUrl: 'login/loginDialog.tpl.html',
        controller: 'LoginDialogCtrl',
      current = $dialog.dialog(options)
      current.open()

    close: ->
      current.close()


.controller 'LoginDialogCtrl', ($scope, loginDialog, users) ->

    $scope.login = ->
      username = $scope.username
      password = $scope.password
      if username
        users.login(username, password).then( -> loginDialog.close())
      else
        email = $scope.email
        # TODO
#        users.findByEmail(email).then (result) ->
#          console.log result

    $scope.cancel = loginDialog.close

    $scope.isValid = ->
      if not $scope.password or not $scope.username and not $scope.email
        false
      else
        true