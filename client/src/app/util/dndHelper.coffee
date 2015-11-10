angular.module('gamEvolve.util.dndHelper', [])

.factory "dndHelper", (currentGame, chips) ->
  # On Chrome, we have to use local storage instead of the HTML5 drag and drop API because of security restrictions.
  # Becuase Angular doesn't like object identity to change at each check, we cache the last object and return it as long as the value doesn't change
  lastDraggedData = null
  getDraggedData: ->
    json = localStorage.getItem("dnd")
    newData = json && JSON.parse(json) || null
    if not _.isEqual(newData, lastDraggedData) 
      console.log("***** updating lastDraggedData from", lastDraggedData, "to", newData, "patches", RW.makePatches(lastDraggedData, newData))
      lastDraggedData = newData
    return lastDraggedData

  setDraggedData: (data) ->
    json = JSON.stringify(data)
    localStorage.setItem("dnd", json)

  clearDraggedData: -> 
    console.log("**** clearing drag data")
    localStorage.removeItem("dnd")

  makeDraggedData: (data) ->
    # Include data about the current version of the game
   return _.extend data, 
      gameId: currentGame.version.gameId
      versionId: currentGame.version.id
      windowId: currentGame.windowId

  dragIsFromSameWindow: (dragData) -> dragData.windowId is currentGame.windowId

  getDraggedGameId: (dragData) -> dragData.gameId 

  # Returns promise
  getGameCodeForCopy: (gameId, versionId) ->
    # Get source game from localStorage
    # TOOD: verify versionId
    return localforage.getItem(gameId).then (sourceGameJson) ->
      if not sourceGameJson then throw new Error("Cannot find game from local storage")
      return JSON.parse(sourceGameJson).data

  # Returns true if the copy is successful, else false
  # Does not update local version
  copySingleChip: (sourceGameCode, targetGameCode, chipType, chipName) ->
    sourceChipCollection = chips.getChipCollection(sourceGameCode, chipType)
    targetChipCollection = chips.getChipCollection(targetGameCode, chipType)

    # Don't bother copying if the things are identical
    if _.isEqual(sourceChipCollection[chipName], targetChipCollection[chipName]) then return false

    # Find new name
    newChipName = if @isChipNameTaken(chipType, chipName) then @findNewChipName(chipType, chipName) else chipName

    # Copy over chip
    targetChipCollection[newChipName] = sourceChipCollection[chipName]
    return true

  # Returns promise for number of chips copied
  # Does not update local version
  copyChip: (gameId, versionId, chip) ->
    # Get source game from localStorage
    return @getGameCodeForCopy(gameId, versionId).then (sourceGameCode) =>
      # Get chip data
      [chipType, chipName] = chips.getChipTypeAndName(chip)

      chipsToCopy = @listChipsToCopy(sourceGameCode, chip)
      copiedChipCount = 0
      for chipToCopy in chipsToCopy
        if @copySingleChip(sourceGameCode, currentGame.version, chipToCopy...) then copiedChipCount++

      return copiedChipCount

  isChipNameTaken: (chipType, chipName) ->
    chipCollection = chips.getChipCollection(currentGame.version, chipType)
    return chipName of chipCollection

  findNewChipName: (chipType, chipName) ->
    chipCollection = chips.getChipCollection(currentGame.version, chipType)
    return @findNewName(_.keys(chipCollection), chipName)

  findNewName: (existingNames, currentName) ->
    nextName = currentName
    nextIndex = 2
    while nextName in existingNames
      nextName = "#{currentName} #{nextIndex}"
      nextIndex++
    return nextName

  # Return list of dependencies like [[chipAType, chipAName], [chipBType, chipBName], ... ]
  listChipsToCopy: (sourceGameCode, chip) ->
    listChipTree = (chip, list = []) =>
      list.push(chip)
      if chip.children
        for child in chip.children
          listChipTree(child, list)
      return list

    recursiveSearch = (chip, dependencies) =>
      [chipType, chipName] = chips.getChipTypeAndName(chip)
      # If our item is already in the list, return early
      if _.contains(dependencies, [chipType, chipName]) then return dependencies

      if chipType not in ["emitter", "splitter", "pipe"]
        # If our item doesn't exist, skip it
        chipCollection = chips.getChipCollection(sourceGameCode, chipType)
        if chipName not of chipCollection then return dependencies

        # Add self to list
        dependencies.push([chipType, chipName])

      # Add references to chips in the board
      if chipType is "circuit"
        circuitDependencies = listChipTree(sourceGameCode.circuits[chipName].board)
        for circuitDependency in circuitDependencies
          recursiveSearch(circuitDependency, dependencies)

      # Add references for transformers and assets referenced in the code
      references = []
      switch chipType
        when "processor"
          @getCodeReferences(sourceGameCode.processors[chipName].update, references)
        when "switch"
          @getCodeReferences(sourceGameCode.switches[chipName].listActiveChildren, references)
          @getCodeReferences(sourceGameCode.switches[chipName].handleSignals, references)
        when "transformer"
          @getCodeReferences(sourceGameCode.transformers[chipName].body, references)

      # Add references for transformers referenced in pins
      switch chipType
        when "emitter"
          for pinName, pinExpression of chip.emitter
            @getCodeReferences(pinExpression, references)
        when "pipe"
          if pipe.initialValue then @getCodeReferences(pipe.initialValue, references)
        when "processor", "switch"
          for pinName, pinExpression of chip.pins.in
            @getCodeReferences(pinExpression, references)
          for pinName, pinExpression of chip.pins.out
            @getCodeReferences(pinExpression, references)

      for reference in references
        recursiveSearch(reference, dependencies)

      return dependencies

    return recursiveSearch(chip, [])

  getTransformerReferences: (code, references = []) ->
    r = /transformers.(\w+)|transformers\[["'](\w*)["']\]/g
    loop
      match = r.exec(code)
      if not match then break
      references.push({ transformer: match[1] || match[2] })
    return references 

  getAssetReferences: (code, references = []) ->
    r = /asset:\s*["'](\w+)["']/g
    loop
      match = r.exec(code)
      if not match then break
      references.push({ asset: match[1] })
    return references 

  getCodeReferences: (code, references = []) ->
    @getTransformerReferences(code, references)
    @getAssetReferences(code, references)
    return references
