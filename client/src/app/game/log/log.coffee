messageToString = (message) ->
  messageParts = for value in message 
    if _.isString(value) then value else JSON.stringify(value) 
  return messageParts.join("  ")

# Returns the chip at the given path 
getChipByPath = (parent, pathParts) ->
  if pathParts.length is 0 then return parent
  if pathParts.length is 1 then return parent.children[pathParts[0]]
  if pathParts[0] of parent.children then return getChipByPath(parent.children[pathParts[0]], _.rest(pathParts))
  throw new Error("Cannot find child chip '#{pathParts[0]}'")

angular.module('gamEvolve.game.log', [])
.controller('LogCtrl', ($scope, gameHistory, currentGame) ->
  formatMessageOrigin = (circuitId, path) -> 
    if not circuitId? or not path? then return "" 
    chip = getChipByPath(currentGame.version.circuits[circuitId].board, path)
    chipName = chip.comment || chip.id || "Untitled #{path.join('.')}"
    return " @ '#{chipName}' "

  # Format a message. Leave strings alone, and format other values as JSON
  onUpdateGameHistory = () ->
    $scope.text = ""
    if gameHistory.data.compilationErrors.length > 0
      $scope.text += "COMPILATION ERRORS:\n"
      for error in gameHistory.data.compilationErrors
        $scope.text += "  #{error}\n"
    for index, frame of gameHistory.data.frames
      if _.some(frame.logMessages, ( (logMessages) -> not _.isEmpty(logMessages) ))
        $scope.text += "FRAME #{parseInt(index) + 1}:\n"
        for circuitId, logMessages of frame.logMessages
          if logMessages.length > 0
            $scope.text += "  CIRCUIT #{circuitId}:\n"
            for message in logMessages
              $scope.text += "    #{message.level}#{formatMessageOrigin(circuitId, message.path)}: #{messageToString(message.message)}\n"
      if frame.errors then break # Stop on first frame where error is found

  $scope.text = ""

  # Bring gameHistory into scope so we can watch it
  $scope.gameHistoryMeta = gameHistory.meta
  $scope.$watch("gameHistoryMeta", onUpdateGameHistory, true)
)
