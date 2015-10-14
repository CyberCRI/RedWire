formatDate = -> moment().format("HH:mm:ss")

isModalShowing = -> $(".modal, .large-modal").length > 0


angular.module('gamEvolve.game.undo', ['gamEvolve.model.undo'])
.controller "UndoCtrl", ($scope, $window, undo, currentGame, cache, gameConverter, WillChangeLocalVersionEvent, GameVersionPublishedEvent) -> 
  currentLocalVersion = null
  initialVersionHasBeenCached = false

  # Bring canUndo() and canRedo() into scope
  $scope.canUndo = -> undo.canUndo()
  $scope.canRedo = -> undo.canRedo()
  $scope.getStatusMessage = -> currentGame.statusMessage

  $scope.undo = -> 
    if not undo.canUndo() then return 

    [currentGame.localVersion, currentGame.version] = undo.undo()
    currentLocalVersion = currentGame.localVersion
    WillChangeLocalVersionEvent.send()
    currentGame.setHasUnpublishedChanges()

  $scope.redo = -> 
    if not undo.canRedo() then return 

    [currentGame.localVersion, currentGame.version] = undo.redo()
    currentLocalVersion = currentGame.localVersion
    WillChangeLocalVersionEvent.send()
    currentGame.setHasUnpublishedChanges()

  onGameVersionPublished = ->
    currentGame.setStatusMessage("Published at #{moment().format("HH:mm:ss")}")
    currentGame.clearHasUnpublishedChanges()
  
  unsubcribeOnGameVersionPublished = GameVersionPublishedEvent.listen(onGameVersionPublished)
  $scope.$on("$destroy", unsubcribeOnGameVersionPublished)

  localCodeIsNewer = (localCode, serverCode) ->
    # For some odd reason _.isEqual() is flagging some equal code as nequal
    localCode.versionNumber == serverCode.versionNumber and RW.makePatches(localCode, serverCode).length > 0

  onUpdateCurrentGame = ->
    if not currentGame.version then return 

    handleUpdate = ->
      # Check that we're not already updated
      if currentLocalVersion isnt currentGame.localVersion 
        # Indicate unsaved changes only if we already have some code in the undo stack
        if not undo.isEmpty() then currentGame.setHasUnpublishedChanges()

        # Store the change in the undo stack
        undo.changeValue(currentGame.localVersion, currentGame.version)
        currentLocalVersion = currentGame.localVersion

        cache.save(currentGame.info.id, currentGame.version).then ->
          currentGame.setStatusMessage("Saved offline at #{formatDate()}")
        .catch (error) ->
          currentGame.setStatusMessage("Offline saving unavailable")
          console.error("Error saving offline:", error)

    # Check if this is the first time the code is loaded (ie. the controller just started)
    if currentLocalVersion
      handleUpdate()
    else
      # Check if code exists in offline cache
      cache.load(currentGame.info.id).then (cachedCode) ->
        if not cachedCode then return 

        # Remove hash keys to get good comparaison
        gameConverter.removeHashKeys(cachedCode)
        gameConverter.removeHashKeys(currentGame.version)

        if localCodeIsNewer(cachedCode, currentGame.version)
          if window.confirm("You have some changes saved offline. Restore your offline version?")
            # Put the old version as the first in the undo stack
            undo.changeValue(currentGame.localVersion, currentGame.version)
            
            # Now update with the new version
            currentGame.setVersion(cachedCode)
            currentGame.updateLocalVersion()
          else
            cache.remove(currentGame.info.id)
      .catch (error) ->
        currentGame.setStatusMessage("Offline saving unavailable")
        console.error("Error saving offline:", error)
        handleUpdate()
      .then(handleUpdate)

  $scope.currentGame = currentGame
  $scope.$watch("currentGame.localVersion", onUpdateCurrentGame, true)

  # Hotkeys
  [undoKey, redoKey] = if $window.navigator and $window.navigator.platform.indexOf("Mac") != -1
    ["command+z", "command+shift+z"]
  else
    ["ctrl+z", "ctrl+y"]
  Mousetrap.bind undoKey, -> 
    if isModalShowing() then return false

    $scope.$apply(-> $scope.undo())
    return false # Block "normal" browser undo
  Mousetrap.bind redoKey, ->
    if isModalShowing() then return false

    $scope.$apply(-> $scope.redo())
    return false # Block "normal" browser redo
