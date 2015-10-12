angular.module( 'gamEvolve', [
  # Order seems to matter
  'templates-app'
  'templates-common'
  'ui.bootstrap'
  'ui.router'
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
  'gamEvolve.game.block'
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
  'gamEvolve.game.like'
  'gamEvolve.game.log'
  'gamEvolve.game.login'
  'gamEvolve.game.login.controls'
  'gamEvolve.game.memory'
  'gamEvolve.game.metrics'
  'gamEvolve.game.overlay'
  'gamEvolve.game.play'
  'gamEvolve.game.player'
  'gamEvolve.game.screenshots'
  'gamEvolve.game.toolbox'
  'gamEvolve.game.toolbox.circuits'
  'gamEvolve.game.toolbox.processors'
  'gamEvolve.game.toolbox.switches'
  'gamEvolve.game.toolbox.transformers'
  'gamEvolve.game.home'
  'gamEvolve.model.chips'
  'gamEvolve.game.undo'
  'gamEvolve.model.games'
  'gamEvolve.model.history'
  'gamEvolve.model.overlay'
  'gamEvolve.model.time'
  'gamEvolve.model.gameplayerstate'
  'gamEvolve.model.undo'
  'gamEvolve.model.users'
  'gamEvolve.util.logger'
  'gamEvolve.util.dndHelper'
  'xeditable'
  'treeRepeat'
  'angulartics'
  'angulartics.google.analytics'
])

.config ( $stateProvider, $urlRouterProvider, $locationProvider ) ->
  # Get rid of those ugly hashes
  $locationProvider.html5Mode(true)
  # Default page is /
  $urlRouterProvider.otherwise('/')

.controller 'AppCtrl', ( $scope, $location, currentGame ) ->
  # The version comes from a global variable in index.html
  $scope.RED_WIRE_VERSION = RED_WIRE_VERSION;

  WARN_LEAVING_MESSAGE = """You have made some changes but not published them. 

    Are you sure you want to leave?"""

  $scope.$on '$stateChangeStart', (event, toState, toParams, fromState, fromParams) ->
    console.log("fromState", fromState, "toState", toState)

    if fromState.name is "game-edit" and currentGame.hasUnpublishedChanges and not window.confirm(WARN_LEAVING_MESSAGE)
      event.preventDefault()

  $scope.$on '$stateChangeSuccess', (event, toState, toParams, fromState, fromParams) ->
    if angular.isDefined( toState.data.pageTitle )
      $scope.pageTitle = toState.data.pageTitle + ' | RedWire'

.run (editableOptions) ->
  # Set options for xeditable
  editableOptions.theme = "bs3"

  # Warn about browser incompatibilities
  if bowser.mobile or bowser.tablet or not (bowser.firefox or bowser.chrome)
    alert """WARNING: RedWire is designed for Firefox and Chrome on the desktop.
      
      It may work on other browsers but we can't guarantee it!"""

