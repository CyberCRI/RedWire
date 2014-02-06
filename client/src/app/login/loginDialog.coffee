angular.module('gamEvolve.login', [
  'ui.bootstrap',
  'gamEvolve.model.users',
  'gamEvolve.login.createUser'
])

.factory 'loginDialog', ($dialog) ->

    current = null

    open: ->
      options =
        backdrop: true
        dialogFade: true
        backdropFade: true
        templateUrl: 'login/loginDialog.tpl.html'
        controller: 'LoginDialogCtrl'
      current = $dialog.dialog(options)
      current.open()

    close: ->
      current.close()


.controller 'LoginDialogCtrl', ($scope, loginDialog, users, createUserDialog, $timeout) ->

    handleError = (error) ->
      $scope.errorMessage = "Wrong credentials"

    logUser = (username, password) ->
      users.login(username, password).then(loginDialog.close, handleError)

    $scope.login = ->
      username = $scope.username
      password = $scope.password
      if username
        logUser(username, password)
      else
        email = $scope.email
        users.findByEmail(email).then (result) ->
          if result.data.length is 0
            $scope.errorMessage = "Email not found"
          else
            logUser(result.data[0].username)

    $scope.cancel = loginDialog.close

    $scope.isValid = ->
      if not $scope.password or not $scope.username and not $scope.email
        false
      else
        true

    $scope.openCreateUserDialog = ->
      loginDialog.close()
      $timeout(createUserDialog.open, 500)

