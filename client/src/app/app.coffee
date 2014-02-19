# Let's keep this list in alphabetical order
angular.module( 'gamEvolve', [
  'templates-app'
  'templates-common'
  'ui.bootstrap'
  'ui.router'
  'ui.state'
  'ui.ace'
  'gamEvolve.model.games'
  'gamEvolve.model.users'
  'gamEvolve.util.logger'
  'gamEvolve.util.boardConverter'
  'gamEvolve.util.gameConverter'
  'gamEvolve.game.assets'
  'gamEvolve.game.boardTree'
  'gamEvolve.game.edit'
  'gamEvolve.game.list'
  'gamEvolve.game.play'
  'gamEvolve.game.import'
  'gamEvolve.game.layers'
  'gamEvolve.game.log'
  'gamEvolve.game.memory'
  'gamEvolve.game.overlay'
  'gamEvolve.game.player'
  'gamEvolve.game.processors'
  'gamEvolve.game.switches'
  'gamEvolve.game.transformers'
  'gamEvolve.login'
  'gamEvolve.about'
  'gamEvolve.model.games'
  'gamEvolve.model.history'
  'gamEvolve.model.overlay'
  'gamEvolve.model.time'
  'gamEvolve.model.users'
  'gamEvolve.util.logger'
  'xeditable'
])

.config( ( $stateProvider, $urlRouterProvider ) ->
  $urlRouterProvider.otherwise( '/game/list' )
)

.controller('AppCtrl', ( $scope, $location ) ->
  $scope.$on '$stateChangeSuccess', (event, toState, toParams, fromState, fromParams) ->
    if angular.isDefined( toState.data.pageTitle )
      $scope.pageTitle = toState.data.pageTitle + ' | RedWire'
)

# Set options for xeditable
.run (editableOptions) ->
  editableOptions.theme = "bs2"
