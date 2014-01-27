# For accessing a chip within a board via it's path
# Takes the board object and the "path" as an array
# Returns [parent, key] where parent is the parent chip and key is last one required to access the child
getLayoutParentAndKey = (parent, pathParts) ->
  if pathParts.length is 0 then return [parent, null]
  if pathParts.length is 1 then return [parent, pathParts[0]]
  if pathParts[0] < parent.children.length then return getLayoutParentAndKey(parent.children[pathParts[0]], _.rest(pathParts))
  throw new Error("Cannot find intermediate key '#{pathParts[0]}'")


angular.module('gamEvolve.game.board', [
  'ui.bootstrap',
])

.controller 'BoardCtrl', ($scope, $dialog, currentGame) ->
  # Get the layout object from the currentGame service, and keep it updated
  $scope.layout = {}

  # Bring currentGame into scope so we can watch it 
  updateBoard = -> $scope.layout = currentGame.version?.layout
  $scope.currentGame = currentGame
  $scope.$watch('currentGame', updateBoard, true)

  $scope.remove = (path) ->
    [parent, index] = getLayoutParentAndKey(currentGame.version.layout, path)
    parent.children.splice(index, 1) # Remove that child

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

  # Listen to clicks on buttons next to each chip on the board, and pass the message 
  # The path of the chip is encoded in an attribute, either editChip or removeChip
  $("body").on "click", "a[editChip]", (event) -> 
    $scope.$apply ->
      chipPath = JSON.parse($(event.currentTarget).attr("editChip"))
      $scope.edit(chipPath)
  $("body").on "click", "a[removeChip]", (event) -> 
    $scope.$apply ->
      chipPath = JSON.parse($(event.currentTarget).attr("removeChip"))
      $scope.remove(chipPath)

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
