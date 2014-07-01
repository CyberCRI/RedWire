messageToString = (message) ->
  messageParts = for value in message 
    if _.isString(value) then value else JSON.stringify(value) 
  return messageParts.join("  ")

formatMessageOrigin = (message) -> if message.path? then " @ [#{message.path.join(', ')}]" else "" 


angular.module('gamEvolve.game.log', [])
.controller('LogCtrl', ($scope, gameHistory) ->
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
              $scope.text += "    #{message.level}#{formatMessageOrigin(message)}: #{messageToString(message.message)}\n"
      if frame.errors then break # Stop on first frame where error is found

  $scope.text = ""

  # Bring gameHistory into scope so we can watch it
  $scope.gameHistoryMeta = gameHistory.meta
  $scope.$watch("gameHistoryMeta", onUpdateGameHistory, true)
)
