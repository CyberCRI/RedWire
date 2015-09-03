# These properties need to be converted from JSON strings to objects upon loading, and back to JSON for saving
JSON_PROPERTIES = [
  "circuits"
  "processors"
  "switches"
  "transformers"
  "assets"
  "redMetricsConfig"
]

# These properties are copied directly
DIRECT_PROPERTIES = [
  "description"
]

# These properties are are part of the game info
META_PROPERTIES = [
  "name"
]

angular.module('gamEvolve.util.gameConverter', [])

.factory "gameConverter", ->
  convertGameVersionFromEmbeddedJson: (gameVersionJson) ->
    gameVersion = 
      id: gameVersionJson.id
      gameId: gameVersionJson.gameId
      versionNumber: gameVersionJson.versionNumber
      fileVersion: gameVersionJson.fileVersion
    for propertyName in JSON_PROPERTIES
      gameVersion[propertyName] = gameVersionJson[propertyName] && JSON.parse(gameVersionJson[propertyName]) || null
    for propertyName in DIRECT_PROPERTIES
      gameVersion[propertyName] = gameVersionJson[propertyName]
    return gameVersion

  convertGameVersionToEmbeddedJson: (gameVersion) ->
    gameVersionJson = 
      id: gameVersion.id
      gameId: gameVersion.gameId
      versionNumber: gameVersion.versionNumber
      fileVersion: gameVersion.fileVersion
    for propertyName in JSON_PROPERTIES
      gameVersionJson[propertyName] = JSON.stringify(gameVersion[propertyName], null, 2)
    for propertyName in DIRECT_PROPERTIES
      gameVersionJson[propertyName] = gameVersion[propertyName]
    return gameVersionJson

  convertGameFromJson: (gameJson) ->
    parsed = JSON.parse(gameJson)
    return {
       info: _.pick(parsed, META_PROPERTIES...)
       version: _.pick(parsed, RW.concatenate(JSON_PROPERTIES, DIRECT_PROPERTIES)...)
    }

  convertGameToJson: (currentGame) ->    
    filteredObject = _.extend({}, 
      _.pick(currentGame.info, META_PROPERTIES...), 
      _.pick(currentGame.version, RW.concatenate(JSON_PROPERTIES, DIRECT_PROPERTIES)...))
    return JSON.stringify(filteredObject, null, 2)

  removeHashKeys: (node) ->
    if "$$hashKey" of node then delete node["$$hashKey"]
    for key, value of node
      if _.isObject(value) then @removeHashKeys(value)
    return node

  bringGameUpToDate: (gameCode) ->
    # Add sound
    if gameCode.fileVersion < 0.3
      for circuitType, circuit of gameCode.circuits
        if "channels" not of circuit.io then circuit.io.channels = []

    # Convert emitters
    updateEmitters = (chip) ->
      if chip.emitter 
        # Convert pins to code
        code = ""
        for dest, src of chip.emitter
          code += "#{dest} = #{src};\n"
        chip.emitter = code

      # Recurse
      if chip.children
        updateEmitters(child) for child in chip.children
      return 

    if gameCode.fileVersion < 0.4
      for circuitType, circuit of gameCode.circuits
        updateEmitters(circuit.board)

    # Update game version
    gameCode.fileVersion = 0.4
    return gameCode
