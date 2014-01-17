angular.module( 'gamEvolve', [
  'templates-app',
  'templates-common',
  'ui.bootstrap',
  'ui.router',
  'ui.state',
  'ui.ace',
  'gamEvolve.model.games',
  'gamEvolve.model.users',
  'gamEvolve.util.logger',
  'gamEvolve.util.tree',
  'gamEvolve.util.boardConverter',
  'gamEvolve.game',
  'gamEvolve.game.edit',
  'gamEvolve.game.log',
  'gamEvolve.game.player',
  'gamEvolve.game.select'
  'gamEvolve.game.time',  
  'gamEvolve.model.games',
  'gamEvolve.model.history',
  'gamEvolve.model.time',
  'gamEvolve.model.users',
  'gamEvolve.util.logger',
])

.config( ( $stateProvider, $urlRouterProvider ) ->
  $urlRouterProvider.otherwise( '/game/1234/edit' )
)

.run( ->
)

.controller('AppCtrl', ( $scope, $location ) ->
  $scope.$on '$stateChangeSuccess', (event, toState, toParams, fromState, fromParams) ->
    if angular.isDefined( toState.data.pageTitle )
      $scope.pageTitle = toState.data.pageTitle + ' | gameEvolve'
)
