angular.module( 'gamEvolve', [
  'templates-app',
  'templates-common',
  'ui.state',
  'ui.route',
  'gamEvolve.home',
  'gamEvolve.about',
  'gamEvolve.games',
  'gamEvolve.logger'
])

.config( ( $stateProvider, $urlRouterProvider ) ->
  $urlRouterProvider.otherwise( '/home' )
)

.run( ->
)

.controller('AppCtrl', ( $scope, $location ) ->
  $scope.$on '$stateChangeSuccess', (event, toState, toParams, fromState, fromParams) ->
    if angular.isDefined( toState.data.pageTitle )
      $scope.pageTitle = toState.data.pageTitle + ' | gameEvolve'
)
