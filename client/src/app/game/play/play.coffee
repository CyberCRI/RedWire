
angular.module('gamEvolve.game.play', [])

.config ($stateProvider) ->
    $stateProvider.state 'play',
      url: '/game/:gameId/play'
      views:
        "main":
          controller: 'PlayCtrl'
          templateUrl: 'game/play/play.tpl.html'
      data:
        pageTitle: 'Play Game'

.controller 'PlayCtrl', ($scope, currentGame) ->
    console.log 'PLAY'