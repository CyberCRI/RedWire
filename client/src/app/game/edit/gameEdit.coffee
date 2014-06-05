
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


.controller 'GameEditCtrl', ($scope, $stateParams, games, currentGame) ->

  games.loadFromId $stateParams.gameId

  # Used by toolbox list
  # TODO: put in own controller
  $scope.isFirstOpen = true

  # When the board changes, update in scope
  updateBoard = -> 
    if currentGame.version?.board
      $scope.board = boardConverter.convert(currentGame.version.board)
  $scope.$watch("currentGame.localVersion", updateBoard, true)

  
.controller 'BasicChipLibraryCtrl', ($scope) ->

  $scope.newSplitter = ->
    splitter:
      from: ''
      bindTo: ''
      index: ''
      
.controller 'LogoCtrl', ($scope, aboutDialog) ->
  $scope.aboutDialog = aboutDialog