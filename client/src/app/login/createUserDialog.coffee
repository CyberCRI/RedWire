angular.module('gamEvolve.login.createUser', [
  'ui.bootstrap',
  'gamEvolve.model.users'
])

.factory 'createUserDialog', ($modal) ->

    current = null

    open: ->
      options =
        backdrop: true
        dialogFade: true
        backdrop: true
        templateUrl: 'login/createUserDialog.tpl.html'
        controller: 'createUserDialogCtrl'
      current = $modal.open(options)

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

