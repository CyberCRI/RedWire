angular.module('gamEvolve.login', [
  'ui.bootstrap',
  'gamEvolve.model.users',
  'gamEvolve.login.createUser'
])

.factory 'loginDialog', ($modal) ->
  current = null

  open: ->
    options =
      backdrop: true
      templateUrl: 'login/loginDialog.tpl.html'
      controller: 'LoginDialogCtrl'
    current = $modal.open(options)

  close: ->
    current.close()


.controller 'LoginDialogCtrl', ($scope, loginDialog, users, createUserDialog, $timeout) ->
  # Need to put 2-way data binding under an object
  $scope.exchange = 
    username: ""
    email: ""
    password: ""
    errorMessage: null

  handleError = (error) ->
    $scope.exchange.errorMessage = "Wrong credentials"

  loginUser = (username, password) ->
    users.login(username, password).then(loginDialog.close, handleError)

  $scope.login = ->
    if $scope.exchange.username
      loginUser($scope.exchange.username, $scope.exchange.password)
    else
      users.findByEmail($scope.exchange.email).then (result) ->
        if result.data.length is 0
          $scope.exchange.errorMessage = "Email not found"
        else
          loginUser(result.data[0].username)

  $scope.cancel = loginDialog.close

  $scope.isValid = ->
    if not $scope.exchange.password or not $scope.exchange.username and not $scope.exchange.email
      false
    else
      true

  $scope.openCreateUserDialog = ->
    loginDialog.close()
    $timeout(createUserDialog.open, 500)

