angular.module('gamEvolve.login.createUser', [
  'ui.bootstrap',
  'gamEvolve.model.users'
])

.factory 'createUserDialog', ($dialog) ->

    current = null

    open: ->
      options =
        backdrop: true
        dialogFade: true
        backdropFade: true
        templateUrl: 'login/createUserDialog.tpl.html'
        controller: 'createUserDialogCtrl'
      current = $dialog.dialog(options)
      current.open()

    close: ->
      current.close()


.controller 'createUserDialogCtrl', ($scope, createUserDialog, users) ->

    $scope.cancel = createUserDialog.close

    $scope.isValid = ->
      unless $scope.username and $scope.email and $scope.password and $scope.verifyPassword
        return false
      return $scope.password is $scope.verifyPassword

    $scope.createUser = ->
      users.createAndLogin($scope.username, $scope.email, $scope.password).then ->
        createUserDialog.close()

