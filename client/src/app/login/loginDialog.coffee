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

    handleError = (error) ->
      $scope.errorMessage = "Wrong credentials"

    login = (username, password) ->
      users.login(username, password).then(loginDialog.close, handleError)

    $scope.login = ->
      username = $scope.username
      password = $scope.password
      if username
        login(username, password)
      else
        email = $scope.email
        users.findByEmail(email).then (result) ->
          if result.data.length is 0
            $scope.errorMessage = "Email not found"
          else
            login(result.data[0].username)

    $scope.cancel = loginDialog.close

    $scope.isValid = ->
      if not $scope.password or not $scope.username and not $scope.email
        false
      else
        true