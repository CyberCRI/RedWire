angular.module( 'gamEvolve', [
  'templates-app',
  'templates-common',
  'ui.bootstrap',
  'ui.router',
  'gamEvolve.home',
  'gamEvolve.about',
  'gamEvolve.model.games',
  'gamEvolve.model.users',
  'gamEvolve.util.logger',
  'gamEvolve.game',
  'gamEvolve.game.edit',
  'gamEvolve.game.time',  
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
