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

  copyChip: (gameId, versionId, chip) ->
    # Get source game from localStorage
    sourceGameCode = @getGameCodeForCopy(gameId, versionId)

    # Get chip data
    [chipType, chipName] = chips.getChipTypeAndName(chip)
    if chipType in ["emitter", "splitter"] then return null # Nothing to do 

    sourceChipCollection = chips.getChipCollection(sourceGameCode, chipType)
    targetChipCollection = chips.getChipCollection(currentGame.version, chipType)

    # Copy over chip
    targetChipCollection[chipName] = sourceChipCollection[chipName]
    currentGame.updateLocalVersion()

  getDependencies: (gameId, versionId, chip) ->
    getTransformerReferences: (code) ->
      r = /transformers.(\w+)|transfromers\[(\w*)\]/g
      matches = loop
        match = r.exec(code)
        if match then match[1] else break
      return matches 

    isChipNameTaken: (chip) ->
      if "processor" of chip then return chip.processor of currentGame.version.processors
      if "switch" of chip then return chip.switch of currentGame.version.switches
      if "circuit" of chip then return chip.circuit of currentGame.version.circuits
      return false

    getNewName: (existingNames, currentName) ->
      nextName = currentName
      nextIndex = 2
      while nextName in existingNames
        nextName = "#{source.name} #{nextIndex}"
        nextIndex++
      return nextName

    ###
      "processor": RW.visitProcessorChip
      "switch": RW.visitSwitchChip
      "splitter": RW.visitSplitterChip
      "emitter": RW.visitEmitterChip
      "circuit": RW.visitCircuitChip
    ###

    listDependenciesForTransformer: (transformer) ->


    listDependencies: (chip, list) ->

    # Get source game from localStorage
    sourceGameJson = localStorage.getItem(gameId)
    if not sourceGameJson then throw new Error("Cannot find game from local storage")
    sourceGame = JSON.parse(sourceGameJson)

    return recursiveSearch(chip, [])
