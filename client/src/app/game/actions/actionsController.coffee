angular.module('gamEvolve.game.actions', [
  'ui.bootstrap',
])
.controller 'ActionsListCtrl', ($scope, $dialog, currentGame) ->
  # Get the actions object from the currentGame service, and keep it updated
  $scope.actions = {}
  $scope.actionNames = []

  # Bring currentGame into scope so we can watch it 
  updateActions = ->
    if currentGame.version?.actions?
      $scope.actions = currentGame.version.actions
      $scope.actionNames = _.keys(currentGame.version.actions)
  $scope.currentGame = currentGame
  $scope.$watch('currentGame', updateActions, true)

  $scope.remove = (name) ->
    delete currentGame.version.actionNames[name]

  $scope.add = () ->
    addActionDialog = $dialog.dialog
      backdrop: true
      dialogFade: true
      backdropFade: true
      backdropClick: false
      templateUrl: 'game/actions/editAction.tpl.html'
      controller: 'EditActionDialogCtrl'
      resolve:
        # This object will be provided to the dialog as a dependency, and serves to communicate between the two
        action: ->
          {
            model:
              name: ""
              paramDefs: {}
              update: ""
            done: (model) ->
              currentGame.version.actions[model.name] = 
                paramDefs: model.paramDefs
                update: model.update

              addActionDialog.close()
            cancel: ->
              addActionDialog.close()
          }
    addActionDialog.open()

  $scope.edit = (actionName) -> 
    action = currentGame.version.actions[actionName]
    editActionDialog = $dialog.dialog
      backdrop: true
      dialogFade: true
      backdropFade: true
      backdropClick: false
      templateUrl: 'game/actions/editAction.tpl.html'
      controller: 'EditActionDialogCtrl'
      resolve:
        # This object will be provided to the dialog as a dependency, and serves to communicate between the two
        action: ->
          {
            model:
              name: actionName
              paramDefs: action.paramDefs
              update: action.update
            done: (model) ->
              # Handle rename case
              if model.name isnt actionName
                delete currentGame.version.actions[actionName]

              currentGame.version.actions[model.name] = 
                paramDefs: model.paramDefs
                update: model.update

              editActionDialog.close()
            cancel: ->
              editActionDialog.close()
          }
    editActionDialog.open()

.controller 'EditActionDialogCtrl', ($scope, action) ->
  # Convert between "paramDef form" used in game serialization and "pin form" used in GUI
  toPins = (paramDefs) ->
    for paramName, paramDef of paramDefs
      name: paramName
      direction: paramDef?.direction || "in"
      default: paramDef?.default || "" 
  toParamDefs = (pins) ->
    paramDefs = {}
    for pin in pins
      paramDefs[pin.name] = 
        direction: pin.direction 
        default: if pin.direction is "in" then pin.default else null
    return paramDefs

  $scope.DIRECTIONS = ["in", "inout", "out"]
  $scope.name = action.model.name
  $scope.pins = toPins(action.model.paramDefs)
  $scope.updateText = action.model.update

  $scope.addPin = -> $scope.pins.push({ name: "", direction: "in" })
  $scope.removePin = (index) -> $scope.arguments.splice(index, 1)

  # Reply with the new data
  $scope.done = -> action.done 
    name: $scope.name
    paramDefs: toParamDefs($scope.pins)
    update: $scope.updateText
  $scope.cancel = -> action.cancel() 
