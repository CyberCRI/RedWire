angular.module('gamEvolve.game.login.controls', [])
.directive "loginControls", ->
  return {
    restrict: "E"
    scope: {}
    templateUrl: "game/login/loginControls.tpl.html"
    controller: ($scope, loggedUser, loginDialog) ->
      $scope.user = loggedUser
      $scope.loginDialog = loginDialog

  }