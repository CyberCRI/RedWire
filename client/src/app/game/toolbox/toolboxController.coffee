angular.module('gamEvolve.game.toolbox', [])
.controller 'ToolboxCtrl', ($scope, $modal, currentGame, ProcessorRenamedEvent, SwitchRenamedEvent, TransformerRenamedEvent) ->

  MODALS = 
    processors:
      templateUrl: 'game/processors/editProcessor.tpl.html'
      controller: 'EditProcessorDialogCtrl'
      renamedEvent: ProcessorRenamedEvent
    switches:
      templateUrl: 'game/switches/editSwitch.tpl.html'
      controller: 'EditSwitchDialogCtrl'
      renamedEvent: SwitchRenamedEvent
    transformers:
      templateUrl: 'game/transformers/editTransformer.tpl.html'
      controller: 'EditTransformerDialogCtrl'
      renamedEvent: TransformerRenamedEvent

  $scope.processors = []
  $scope.switches = []
  $scope.transformers = []

  # Watch currentGame and update our scope
  updateItems = ->
    if not currentGame.version then return 
    for itemType in ["processors", "switches", "transformers"]
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
      when "processors"
        processor: name
        pins:
          in: {}
          out: {}
      when "switches"
        switch: name
        pins:
          in: {}
          out: {}
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
        delete currentGame.version[itemType][name]

      setModelFromDialog(itemType, newModel)
      currentGame.updateLocalVersion()
