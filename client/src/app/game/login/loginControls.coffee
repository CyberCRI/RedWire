angular.module('gamEvolve.game.login.controls', [])
.directive "loginControls", ->
  return {
    restrict: "E"
    scope: {}
    templateUrl: "game/login/loginControls.tpl.html"
    controller: ($scope, loggedUser, users, loginDialog) ->
      $scope.loggedUser = loggedUser
      $scope.users = users
      $scope.loginDialog = loginDialog
  }