# For accessing a chip within a board via it's path
# Takes the board object and the "path" as an array
# Returns [parent, key] where parent is the parent chip and key is last one required to access the child
getBoardParentAndKey = (parent, pathParts) ->
  if pathParts.length is 0 then return [parent, null]
  if pathParts.length is 1 then return [parent, pathParts[0]]
  if pathParts[0] < parent.children.length then return getBoardParentAndKey(parent.children[pathParts[0]], _.rest(pathParts))
  throw new Error("Cannot find intermediate key '#{pathParts[0]}'")

getBoardChip = (parent, pathParts) -> 
  if pathParts.length is 0 then return parent

  [foundParent, index] = getBoardParentAndKey(parent, pathParts)
  return foundParent.children[index]

enumerateModelKeys = (model, prefix = ["model"], keys = []) ->
  for name, value of model
    keys.push(GE.appendToArray(prefix, name).join("."))
    if GE.isOnlyObject(value) then enumerateModelKeys(value, GE.appendToArray(prefix, name), keys)
  return keys

enumerateServiceKeys = (services,  keys = []) ->
  # TODO: dig down a bit into what values the services provide
  for name of services
    keys.push(["services", name].join("."))
  return keys

enumeratePinDestinations = (gameVersion) ->
  destinations = enumerateModelKeys(gameVersion.model)
  enumerateServiceKeys(GE.services, destinations)
  return destinations

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
    [parent, index] = getBoardParentAndKey(currentGame.version.layout, path)
    parent.children.splice(index, 1) # Remove that child

  ###
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
  ###

  $scope.edit = (path) -> 
    chip = getBoardChip(currentGame.version.layout, path)

    # Determine type of chip
    if "action" of chip
      # TODO
    else if "process" of chip
      # TODO
    else if "foreach" of chip
      # TODO
    else if "send" of chip
      editDialog = $dialog.dialog
        backdrop: true
        dialogFade: true
        backdropFade: true
        backdropClick: false
        templateUrl: 'game/board/editBoardSend.tpl.html'
        controller: 'EditBoardSendDialogCtrl'
        resolve:
          # This object will be provided to the dialog as a dependency, and serves to communicate between the two
          liaison: ->
            {
              model: GE.cloneData(chip)
              done: (model) ->
                # Overwrite the chip
                _.extend(chip, model) 
                editDialog.close()
              cancel: ->
                editDialog.close()
            }
      editDialog.open()

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

.controller 'EditBoardSendDialogCtrl', ($scope, liaison, currentGame) ->
  # Convert between "paramDef form" used in game serialization and "pin form" used in GUI
  $scope.OUTPUTS = enumeratePinDestinations(currentGame.version)
  $scope.name = liaison.model.comment
  $scope.pins = ({ input: input, output: output } for output, input of liaison.model.send)

  $scope.addPin = -> $scope.pins.push({ input: "", output: "" })
  $scope.removePin = (index) -> $scope.pins.splice(index, 1)

  # Reply with the new data
  $scope.done = -> liaison.done 
    comment: $scope.name
    send: _.object(([output, input] for {input: input, output: output} in $scope.pins))
  $scope.cancel = -> liaison.cancel() 
