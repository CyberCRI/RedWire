angular.module('gamEvolve.game.login.createUser', [
  'ui.bootstrap',
  'gamEvolve.model.users'
])

.factory 'createUserDialog', ($modal) ->
  current = null

  open: ->
    options =
      backdrop: true
      templateUrl: 'game/login/createUserDialog.tpl.html'
      controller: 'createUserDialogCtrl'
    current = $modal.open(options)

  close: ->
    current.close()

.controller 'createUserDialogCtrl', ($scope, createUserDialog, users) ->
  $scope.exchange = 
    username: ""
    email: ""
    password: ""
    verifyPassword: ""

  $scope.cancel = createUserDialog.close

  $scope.isValid = ->
    unless $scope.exchange.username and $scope.exchange.email and $scope.exchange.password and $scope.exchange.verifyPassword
      return false
    return $scope.exchange.password is $scope.exchange.verifyPassword

  $scope.createUser = ->
    users.createAndLogin($scope.exchange.username, $scope.exchange.email, $scope.exchange.password)
      .then(-> createUserDialog.close())
      .catch (response) ->
        errorTexts = ("#{key} #{value}" for key, value of response.data.errors)
        $scope.errorMessage = errorTexts.join(". ")
