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
  'gamEvolve.game.play'
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

.controller('AppCtrl', ( $scope, $location, $window ) ->
  $scope.$on '$stateChangeStart', (event, toState, toParams, fromState, fromParams) ->
    console.log("fromState", fromState, "toState", toState)

    # Warn about losing changes if the leaves the edit game screen
    if fromState.name is "game-edit" and not window.confirm("You will lose all your changes. Are you sure?")
      event.preventDefault()
      $window.history.back()

    # Warn about losing editing changes when the user navigates away to a different site
    window.onbeforeunload = if toState.name is "game-edit" then -> "You will lose all your changes. Are you sure?"

  $scope.$on '$stateChangeSuccess', (event, toState, toParams, fromState, fromParams) ->
    if angular.isDefined( toState.data.pageTitle )
      $scope.pageTitle = toState.data.pageTitle + ' | RedWire'
)

# Set options for xeditable
.run (editableOptions) ->
  editableOptions.theme = "bs2"
