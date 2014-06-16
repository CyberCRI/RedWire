
angular.module('gamEvolve.game.edit', [
  'flexyLayout'
  'gamEvolve.game.memory'
  'gamEvolve.game.edit.header'
])


.config ($stateProvider) ->
  $stateProvider.state 'game-edit',
    url: '/game/:gameId/edit'
    views: 
      "main":
        controller: 'GameEditCtrl'
        templateUrl: 'game/edit/gameEdit.tpl.html'
    data: 
      pageTitle: 'Edit Game'


.controller 'GameEditCtrl', ($scope, $stateParams, games) ->

  games.loadFromId $stateParams.gameId

  # Used by toolbox list
  # TODO: put in own controller
  $scope.isFirstOpen = true
      
.controller 'LogoCtrl', ($scope, aboutDialog) ->
  $scope.aboutDialog = aboutDialog