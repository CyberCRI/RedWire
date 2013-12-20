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
  'gamEvolve.game',
  'gamEvolve.game.edit',
  'gamEvolve.game.select'
  'gamEvolve.game.time',  
  'gamEvolve.game.log',
  'gamEvolve.game.player',
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
