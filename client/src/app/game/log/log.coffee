angular.module('gamEvolve.game.log', [])
.controller('LogCtrl', ($scope, gameHistory) ->
  # Format a message. Leave strings alone, and format other values as JSON
  messageToString = (message) ->
    messageParts = for value in message 
      if _.isString(value) then value else JSON.stringify(value) 
    return messageParts.join("  ")

  onUpdateGameHistory = () ->
    $scope.text = ""
    for index, frame of gameHistory.data.frames
      if frame.logMessages.length > 0
        $scope.text += "FRAME #{parseInt(index) + 1}:\n"
        for message in frame.logMessages
          $scope.text += "  #{message.level}: #{messageToString(message.message)}\n"

  $scope.text = ""
  $scope.aceLoaded = (editor) -> 
    editor.setReadOnly(true)

  # Bring gameHistory into scope so we can watch it
  $scope.gameHistoryMeta = gameHistory.meta
  $scope.$watch("gameHistoryMeta", onUpdateGameHistory, true)
)
