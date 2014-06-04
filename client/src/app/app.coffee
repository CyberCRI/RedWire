# Let's keep this list in alphabetical order
angular.module( 'gamEvolve', [
  'templates-app'
  'templates-common'
  'ui.bootstrap'
  'ui.router'
  'ui.state'
  'ui.ace'
  'gamEvolve.model.cache'
  'gamEvolve.model.games'
  'gamEvolve.model.users'
  'gamEvolve.util.eventBus'
  'gamEvolve.util.logger'
  'gamEvolve.util.gameConverter'
  'gamEvolve.game.about'
  'gamEvolve.game.assets'
  'gamEvolve.game.boardTree'
  'gamEvolve.game.boardNodes'
  'gamEvolve.game.edit'
  'gamEvolve.game.embed'
  'gamEvolve.game.list'
  'gamEvolve.game.play'
  'gamEvolve.game.import'
  'gamEvolve.game.layers'
  'gamEvolve.game.log'
  'gamEvolve.game.login'
  'gamEvolve.game.memory'
  'gamEvolve.game.overlay'
  'gamEvolve.game.play'
  'gamEvolve.game.player'
  'gamEvolve.game.processors'
  'gamEvolve.game.switches'
  'gamEvolve.game.transformers'
  'gamEvolve.login'
  'gamEvolve.about'
  'gamEvolve.model.chips'
  'gamEvolve.game.undo'
  'gamEvolve.model.games'
  'gamEvolve.model.history'
  'gamEvolve.model.overlay'
  'gamEvolve.model.time'
  'gamEvolve.model.undo'
  'gamEvolve.model.users'
  'gamEvolve.util.logger'
  'xeditable'
  'treeRepeat'
])

.config( ( $stateProvider, $urlRouterProvider ) ->
  $urlRouterProvider.otherwise( '/game/list' )
)

.controller('AppCtrl', ( $scope, $location ) ->
  $scope.$on '$stateChangeStart', (event, toState, toParams, fromState, fromParams) ->
    console.log("fromState", fromState, "toState", toState)

    if fromState.name is "game-edit" and not window.confirm("You will lose all your changes. Are you sure?")
      event.preventDefault()

    # Warn about losing editing changes when the user navigates away to a different site
    window.onbeforeunload = if toState.name is "game-edit" then -> "You will lose all your changes. Are you sure?"

  $scope.$on '$stateChangeSuccess', (event, toState, toParams, fromState, fromParams) ->
    if angular.isDefined( toState.data.pageTitle )
      $scope.pageTitle = toState.data.pageTitle + ' | RedWire'
)

# Set options for xeditable
.run (editableOptions) ->
  editableOptions.theme = "bs3"
