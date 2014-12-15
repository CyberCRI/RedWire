angular.module( 'gamEvolve', [
  # Order seems to matter
  'templates-app'
  'templates-common'
  'ui.bootstrap'
  'ui.router'
  'ui.state'
  'ui.ace'
  'ui.sortable'
  'ngSanitize'
  'gamEvolve.model.cache'
  'gamEvolve.model.games'
  'gamEvolve.model.users'
  'gamEvolve.model.circuits'
  'gamEvolve.util.eventBus'
  'gamEvolve.util.logger'
  'gamEvolve.util.gameConverter'
  'gamEvolve.util.pins'
  'gamEvolve.game.about'
  'gamEvolve.game.assets'
  'gamEvolve.game.boardTree'
  'gamEvolve.game.boardNodes'
  'gamEvolve.game.channels'
  'gamEvolve.game.description'
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
  'gamEvolve.game.toolbox'
  'gamEvolve.game.toolbox.circuits'
  'gamEvolve.game.toolbox.processors'
  'gamEvolve.game.toolbox.switches'
  'gamEvolve.game.toolbox.transformers'
  'gamEvolve.model.chips'
  'gamEvolve.game.undo'
  'gamEvolve.model.games'
  'gamEvolve.model.history'
  'gamEvolve.model.overlay'
  'gamEvolve.model.time'
  'gamEvolve.model.undo'
  'gamEvolve.model.users'
  'gamEvolve.util.logger'
  'gamEvolve.util.dndHelper'
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

.run (editableOptions) ->
  # Set options for xeditable
  editableOptions.theme = "bs3"

  # Warn about browser incompatibilities
  if bowser.mobile or bowser.tablet or not (bowser.firefox or bowser.chrome)
    alert """WARNING: RedWire is designed for Firefox and Chrome on the desktop.
      
      It may work on other browsers but we can't guarantee it!"""

