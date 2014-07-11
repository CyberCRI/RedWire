angular.module('gamEvolve.game.toolbox', [])
.controller 'ToolboxCtrl', ($scope, $modal, currentGame, circuits, ProcessorRenamedEvent, SwitchRenamedEvent, TransformerRenamedEvent, CircuitRenamedEvent) ->

  MODALS = 
    processors:
      templateUrl: 'game/toolbox/editProcessor.tpl.html'
      controller: 'EditProcessorDialogCtrl'
      renamedEvent: ProcessorRenamedEvent
    switches:
      templateUrl: 'game/toolbox/editSwitch.tpl.html'
      controller: 'EditSwitchDialogCtrl'
      renamedEvent: SwitchRenamedEvent
    transformers:
      templateUrl: 'game/toolbox/editTransformer.tpl.html'
      controller: 'EditTransformerDialogCtrl'
      renamedEvent: TransformerRenamedEvent
    circuits:
      templateUrl: 'game/toolbox/editCircuit.tpl.html'
      controller: 'EditCircuitDialogCtrl'
      renamedEvent: CircuitRenamedEvent

  $scope.processors = []
  $scope.switches = []
  $scope.transformers = []
  $scope.circuits = []

  # Watch currentGame and update our scope
  updateItems = ->
    if not currentGame.version then return 
    for itemType in ["processors", "switches", "transformers", "circuits"]
      $scope[itemType] = _.keys(currentGame.version[itemType])
  $scope.$watch((-> currentGame.localVersion), updateItems)

  openModal = (templateUrl, dialogControllerName, model, onDone) -> 
    dialog = $modal.open
      backdrop: "static"
      templateUrl: templateUrl
      size: "lg"
      controller: dialogControllerName
      resolve:
        # This object will be provided to the dialog as a dependency, and serves to communicate between the two
        liaison: ->
          model: model
          done: (model) -> 
            onDone(model)
            dialog.close()
          cancel: ->
            dialog.close()

  getModelForDialog = (itemType, name, model) ->
    switch itemType
      when "processors"
        name: name
        pinDefs: currentGame.version.processors[name].pinDefs
        update: currentGame.version.processors[name].update
      when "switches"
        name: name
        pinDefs: currentGame.version.switches[name].pinDefs
        listActiveChildren: currentGame.version.switches[name].listActiveChildren
        handleSignals: currentGame.version.switches[name].handleSignals
      when "transformers"
        name: name
        arguments: currentGame.version.transformers[name].args
        body: currentGame.version.transformers[name].body
      when "circuits"
        name: name
        pinDefs: currentGame.version.circuits[name].pinDefs
      else 
        throw new Error("Unknown item type '#{itemType}'")

  setModelFromDialog = (itemType, model) ->
    switch itemType
      when "processors"
        currentGame.version.processors[model.name] = 
          pinDefs: model.pinDefs
          update: model.update
      when "switches"
        currentGame.version.switches[model.name] = 
          pinDefs: model.pinDefs
          listActiveChildren: model.listActiveChildren
          handleSignals: model.handleSignals 
      when "transformers"
        currentGame.version.transformers[model.name] = 
          args: model.arguments
          body: model.body
      when "circuits"
        # If the circuit doesn't exist, create it with empty data
        if model.name not of currentGame.version.circuits
          currentGame.version.circuits[model.name] = 
            board: 
              switch: "Do in Parallel"
              comment: model.name
              pins:
                in: {}
                out: {}
              children: []
            assets: {}
            memory: {}
            io: 
              layers: []
        # Set the data returned by the user
        currentGame.version.circuits[model.name].name = model.name
        currentGame.version.circuits[model.name].pinDefs = model.pinDefs
      else 
        throw new Error("Unknown item type '#{itemType}'")

  makeEmptyItemForDialog = (itemType) ->
    switch itemType
      when "processors"
        name: ""
        pinDefs: {}
        update: ""
      when "switches"
        name: ""
        pinDefs: {}
        listActiveChildren: ""
        handleSignals: ""
      when "transformers"
        name: ""
        arguments: []
        body: ""
      when "circuits"
        name: ""
        pinDefs: {}
      else 
        throw new Error("Unknown item type '#{itemType}'")

  $scope.itemForDrag = (itemType, name) -> 
    switch itemType
      when "emitters"
        emitter: { }
      when "splitters"
        splitter:
          from: ''
          bindTo: ''
          index: ''
        children: []
      when "processors"
        processor: name
        pins:
          in: {}
          out: {}
        children: []
      when "switches"
        switch: name
        pins:
          in: {}
          out: {}
        children: []
      when "circuits"
        circuit: name
        id: name
        pins:
          in: {}
          out: {}
        children: []
      when "transformers"
        transformer: name
      else 
        throw new Error("Unknown item type '#{itemType}'")

  $scope.removeItem = (itemType, name) ->
    delete currentGame.version[itemType][name]
    currentGame.updateLocalVersion()

  $scope.addItem = (itemType) ->
    openModal MODALS[itemType].templateUrl, MODALS[itemType].controller, makeEmptyItemForDialog(itemType), (newModel) ->
      setModelFromDialog(itemType, newModel)
      currentGame.updateLocalVersion()

  $scope.editItem = (itemType, name) -> 
    openModal MODALS[itemType].templateUrl, MODALS[itemType].controller, getModelForDialog(itemType, name), (newModel) ->
      # Handle rename case
      if newModel.name isnt name
        MODALS[itemType].renamedEvent.send
          oldName: name
          newName: newModel.name

        # Move the data to the new name 
        currentGame.version[itemType][newModel.name] = currentGame.version[itemType][name]
        delete currentGame.version[itemType][name]

      setModelFromDialog(itemType, newModel)
      currentGame.updateLocalVersion()

  $scope.changeCircuit = (circuitName) ->
    # Switch to editing the circuit type, not a particular instance
    circuits.currentCircuitMeta = new RW.CircuitMeta(null, circuitName)

.directive "toolboxDropzone", (currentGame, dndHelper, chips) ->
  restrict: 'A',
  link: (scope, element, attrs) ->
    acceptDrop = (event) ->
      draggedData = dndHelper.getDraggedData()
      if dndHelper.dragIsFromSameWindow(draggedData) then return false 
      [chipType, chipName] = chips.getChipTypeAndName(draggedData.node) 
      return chipType not in ["emitter", "splitter"] 

    el = element[0]
    dragster = new Dragster(el)
    el.addEventListener "dragster:enter", (event) ->
      # The data transfer info is hidden under detail
      event.dataTransfer = event.detail.dataTransfer
      if not acceptDrop(event) then return false

      console.log("enter")
      el.classList.add('drag-over')
      return false
    el.addEventListener "dragster:leave", (event) ->
      # The data transfer info is hidden under detail
      event.dataTransfer = event.detail.dataTransfer
      if not acceptDrop(event) then return false

      console.log("leave")
      el.classList.remove('drag-over')
      return false
    el.addEventListener "dragover", (event) -> 
      if not acceptDrop(event) then return false

      event.preventDefault?() 
      event.stopPropogation?() 
      event.dataTransfer.dropEffect = 'move'
      return false
    el.addEventListener "drop", (event) -> 
      if not acceptDrop(event) then return false

      event.preventDefault?() 
      event.stopPropogation?() 
      console.log("drop")
      el.classList.remove('drag-over')
      dragster.reset()

      draggedData = dndHelper.getDraggedData()
      copiedChipCount = dndHelper.copyChip(draggedData.gameId, draggedData.versionId, draggedData.node)
      if copiedChipCount > 0 then currentGame.updateLocalVersion()

      return false
