angular.module( 'ngBoilerplate', [
  'templates-app',
  'templates-common',
  'ngBoilerplate.home',
  'ngBoilerplate.about',
  'ui.state',
  'ui.route'
])

.config( ( $stateProvider, $urlRouterProvider ) -> 
  $urlRouterProvider.otherwise( '/home' )
)

.run( ->
)

.controller('AppCtrl', ( $scope, $location ) -> 
  $scope.$on '$stateChangeSuccess', (event, toState, toParams, fromState, fromParams) ->
    if angular.isDefined( toState.data.pageTitle )
      $scope.pageTitle = toState.data.pageTitle + ' | ngBoilerplate' 
)
