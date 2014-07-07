angular.module('gamEvolve.util.dndHelper', [])

.factory "dndHelper", (currentGame, chips) ->
  getDraggedData: (event) ->
    # On Chrome, we have to use local storage because of security restrictions
    json = event.dataTransfer.getData('application/json') || localStorage.getItem("dnd")
    return json && JSON.parse(json) || null

  setDraggedData: (event, data) ->
    # On Chrome, we have to use local storage because of security restrictions
    json = JSON.stringify(data)
    event.dataTransfer.setData('application/json', json)
    localStorage.setItem("dnd", json)

  dragIsFromSameWindow: (event) -> @getDraggedData(event)?.windowId is currentGame.windowId

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
  copyChip: (gameId, versionId, chip) ->
    # Get source game from localStorage
    sourceGameCode = @getGameCodeForCopy(gameId, versionId)

    # Get chip data
    [chipType, chipName] = chips.getChipTypeAndName(chip)

    chipsToCopy = @listChipsToCopy(sourceGameCode, chipType, chipName)
    copiedChipCount = 0
    for chipToCopy in chipsToCopy
      if @copySingleChip(sourceGameCode, currentGame.version, chipToCopy...) then copiedChipCount++

    if copiedChipCount > 0 then currentGame.updateLocalVersion()
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
  listChipsToCopy: (sourceGameCode, chipType, chipName) ->
    listChipTree = (chip, list = []) =>
      list.push(chips.getChipTypeAndName(chip))
      if chip.children
        for child in chip.children
          listChipTree(child, list)
      return list

    recursiveSearch = (chipType, chipName, dependencies) =>
      # Add self to list
      if chipType not in ["emitter", "splitter"]
        dependencies.push([chipType, chipName])

      # Add references to chips in the board
      if chipType is "circuit"
        circuitDependencies = listChipTree(sourceGameCode.circuits[chipName].board)
        for circuitDependency in circuitDependencies
          recursiveSearch(circuitDependency..., dependencies)

      # Add references for transformers referenced in the code
      transformerReferences = []
      chipCollection = chips.getChipCollection(sourceGameCode, chipType)
      switch chipType
        when "processor"
          @getTransformerReferences(chipCollection[chipName].update, transformerReferences)
        when "switch"
          @getTransformerReferences(chipCollection[chipName].listActiveChildren, transformerReferences)
          @getTransformerReferences(chipCollection[chipName].handleSignals, transformerReferences)
        when "transformer"
          @getTransformerReferences(chipCollection[chipName].body, transformerReferences)

      for transformerReference in transformerReferences
        recursiveSearch(transformerReference..., dependencies)

      return dependencies

    return recursiveSearch(chipType, chipName, [])

  getTransformerReferences: (code, references = []) ->
    r = /transformers.(\w+)|transfromers\[(\w*)\]/g
    loop
      match = r.exec(code)
      if not match then break
      references.push(["transformer", match[1]])
    return references 

