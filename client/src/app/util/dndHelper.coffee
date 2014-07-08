angular.module('gamEvolve.util.dndHelper', [])

.factory "dndHelper", (currentGame, chips) ->
  # On Chrome, we have to use local storage instead of the HTML5 drag and drop API because of security restrictions.
  getDraggedData: ->
    json = localStorage.getItem("dnd")
    return json && JSON.parse(json) || null

  setDraggedData: (data) ->
    json = JSON.stringify(data)
    localStorage.setItem("dnd", json)

  clearDraggedData: -> localStorage.removeItem("dnd")

  dragIsFromSameWindow: (dragData) -> dragData.windowId is currentGame.windowId

  getGameCodeForCopy: (gameId, versionId) ->
    # Get source game from localStorage
    # TOOD: verify versionId
    sourceGameJson = localStorage.getItem(gameId)
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

  # Returns number of chips copied
  # Does not update local version
  copyChip: (gameId, versionId, chip) ->
    # Get source game from localStorage
    sourceGameCode = @getGameCodeForCopy(gameId, versionId)

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
      # If our item doesn't exist, skip it
      chipCollection = chips.getChipCollection(sourceGameCode, chipType)
      if chipName not of chipCollection then return dependencies

      # Add self to list
      if chipType not in ["emitter", "splitter"]
        dependencies.push([chipType, chipName])

      # Add references to chips in the board
      if chipType is "circuit"
        circuitDependencies = listChipTree(sourceGameCode.circuits[chipName].board)
        for circuitDependency in circuitDependencies
          recursiveSearch(circuitDependency, dependencies)

      # Add references for transformers referenced in the code
      transformerReferences = []
      switch chipType
        when "processor"
          @getTransformerReferences(sourceGameCode.processors[chipName].update, transformerReferences)
        when "switch"
          @getTransformerReferences(sourceGameCode.switches[chipName].listActiveChildren, transformerReferences)
          @getTransformerReferences(sourceGameCode.switches[chipName].handleSignals, transformerReferences)
        when "transformer"
          @getTransformerReferences(sourceGameCode.transformers[chipName].body, transformerReferences)

      # Add references for transformers referenced in pins
      switch chipType
        when "emitter"
          for pinName, pinExpression of chip.emitter
            @getTransformerReferences(pinExpression, transformerReferences)
        when "processor", "switch"
          for pinName, pinExpression of chip.pins.in
            @getTransformerReferences(pinExpression, transformerReferences)
          for pinName, pinExpression of chip.pins.out
            @getTransformerReferences(pinExpression, transformerReferences)

      for transformerName in transformerReferences
        recursiveSearch({ transformer: transformerName }, dependencies)

      return dependencies

    return recursiveSearch(chip, [])

  getTransformerReferences: (code, references = []) ->
    r = /transformers.(\w+)|transformers\[["'](\w*)["']\]/g
    loop
      match = r.exec(code)
      if not match then break
      references.push(match[1] || match[2])
    return references 

