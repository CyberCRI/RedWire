# TODO Delete - The next two methods are now in currentGame service

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

  showDialog = (templateUrl, controller, model, onDone) -> 
    dialog = $dialog.dialog
      backdrop: true
      dialogFade: true
      backdropFade: true
      backdropClick: false
      templateUrl: templateUrl
      controller: controller
      resolve:
        # This object will be provided to the dialog as a dependency, and serves to communicate between the two
        liaison: ->
          {
            model: GE.cloneData(model)
            done: (newModel) ->
              onDone(newModel) 
              dialog.close()
            cancel: ->
              dialog.close()
          }
    dialog.open()

  $scope.remove = (path) ->
    [parent, index] = getBoardParentAndKey(currentGame.version.board, path)
    parent.children.splice(index, 1) # Remove that child

  $scope.edit = (path) ->
    chip = getBoardChip(currentGame.version.board, path)
    # Determine type of chip
    if "processor" of chip
      showDialog 'game/board/editBoardProcessor.tpl.html', 'EditBoardProcessorDialogCtrl', chip, (model) ->
        _.extend(chip, model)
    else if "switch" of chip
      showDialog 'game/board/editBoardProcessor.tpl.html', 'EditBoardProcessorDialogCtrl', chip, (model) ->
        _.extend(chip, model)
    else if "splitter" of chip
      showDialog 'game/board/editBoardSplitter.tpl.html', 'EditBoardSplitterDialogCtrl', chip, (model) ->
        _.extend(chip, model)
    else if "emitter" of chip
      showDialog 'game/board/editBoardEmitter.tpl.html', 'EditBoardEmitterDialogCtrl', chip, (model) ->
        _.extend(chip, model)
      
  $scope.$on 'editChipButtonClick', (event, chipPath) ->
    $scope.edit(chipPath)

  $scope.$on 'removeChipButtonClick', (event, chipPath) ->
    $scope.remove(chipPath)


.controller 'EditBoardEmitterDialogCtrl', ($scope, liaison, currentGame) ->
  $scope.DESTINATIONS = enumeratePinDestinations(currentGame.version)
  $scope.name = liaison.model.comment
  # Convert between "paramDef form" used in game serialization and "pin form" used in GUI
  $scope.pins = ({ input: input, output: output } for output, input of liaison.model.emitter)

  $scope.addPin = -> $scope.pins.push({ input: "", output: "" })
  $scope.removePin = (index) -> $scope.pins.splice(index, 1)

  # Reply with the new data
  $scope.done = -> liaison.done 
    comment: $scope.name
    emitter: _.object(([output, input] for {input: input, output: output} in $scope.pins))
  $scope.cancel = -> liaison.cancel() 


.controller 'EditBoardSplitterDialogCtrl', ($scope, liaison, currentGame) ->
  $scope.DESTINATIONS = enumeratePinDestinations(currentGame.version)
  $scope.name = liaison.model.comment
  $scope.from = liaison.model.foreach.from
  $scope.bindTo = liaison.model.foreach.bindTo
  $scope.index = liaison.model.foreach.index

  # Reply with the new data
  $scope.done = -> liaison.done 
    comment: $scope.name
    foreach:
      from: $scope.from
      bindTo: $scope.bindTo
      index: $scope.index
  $scope.cancel = -> liaison.cancel() 


.controller 'EditBoardProcessorDialogCtrl', ($scope, liaison, currentGame) ->
  # Source must start with "model" or "services", then a dot, then some more text or indexing 
  sourceIsSimple = (source) -> /^(model|services)\.[\w.\[\]]+$/.test(source)

  # Drain must be a simple mapping of the parameter
  drainIsSimple = (name, outValues) -> "params.#{name}" in _.values(outValues)

  # Determine if pin destination is "simple" or "custom"
  determineLinkage = (name, direction, inValues, outValues) ->
    if direction in ["in", "inout"] and not sourceIsSimple(inValues[name]) then return "custom" 
    if direction in ["out", "inout"] and not drainIsSimple(name, outValues) then return "custom" 
    # The drain and source destinations must be equal
    if direction is "inout" and outValues[inValues[name]] isnt "params.#{name}" then return "custom"
    return "simple" 

  # Only valid if determineLinkage() returns "simple"
  getSimpleDestination = (name, direction, inValues, outValues) ->
    if direction in ["in", "inout"] then return inValues[name] 
    for destination, expression in outValues
      if expression is "params.#{name}" then return destination
    throw new Error("Cannot find simple destination for parameter '#{name}'")

  findParameterReferences = (name, outValues) ->
    return ({ drain: drain, source: source } for drain, source of outValues when source.indexOf("params.#{name}") != -1)

  convertPinsToModel = (pins) ->
    params = 
      in: {}
      out: {}
    for pin in pins
      if pin.direction in ["in", "inout"]
        params.in[pin.name] = if pin.linkage is "simple" then pin.simpleDestination else pin.customDestinations.in
      if pin.direction in ["out", "inout"]
        if pin.linkage is "simple" 
          params.out[pin.simpleDestination] = "params.#{pin.name}"
        else
          for destination in pin.customDestinations.out
            params.out[destination.drain] = destination.source
    return params

  $scope.LINKAGES = ["simple", "custom"]
  $scope.DESTINATIONS = enumeratePinDestinations(currentGame.version)
  $scope.name = liaison.model.comment

  # Depending on if this is an processor or a switch, get the right kind of data 
  # TODO: move this to calling controller?
  typeDef = null
  if "processor" of liaison.model
    $scope.kind = "Processor"
    $scope.type = liaison.model.processor
    typeDef = currentGame.version.processors[$scope.type]
  else if "switch" of liaison.model
    $scope.kind = "Switch" 
    $scope.type = liaison.model.switch
    typeDef = currentGame.version.switches[$scope.type]
  else
    throw new Error("Model is not a processor or switch")

  # TODO: refactor into function
  $scope.pins = []
  for paramName, paramDef of typeDef.paramDefs
    pin = 
      name: paramName
      direction: paramDef?.direction ? "in"
      default: paramDef?.default
      simpleDestination: ""
      customDestinations:
        in: ""
        out: []
    pin.linkage = determineLinkage(paramName, pin.direction, liaison.model.params.in, liaison.model.params.out)
    if pin.linkage == "simple" 
      pin.simpleDestination = getSimpleDestination(paramName, pin.direction, liaison.model.params.in, liaison.model.params.out)
    else
      pin.customDestinations.in = liaison.model.params.in[paramName]
      pin.customDestinations.out = findParameterReferences(paramName, liaison.model.params.out)
    $scope.pins.push(pin)

  $scope.addCustomDestination = (pinName) -> 
    pin = _.where($scope.pins, { name: pinName })[0]
    pin.customDestinations.out.push({ drain: "", source: "" })
  $scope.removeCustomDestination = (pinName, index) -> 
    pin = _.where($scope.pins, { name: pinName })[0]
    pin.customDestinations.out.splice(index, 1)

  # Reply with the new data
  $scope.done = -> liaison.done 
    comment: $scope.name
    params: convertPinsToModel($scope.pins)
  $scope.cancel = -> liaison.cancel() 
