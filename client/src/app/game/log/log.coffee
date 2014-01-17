angular.module('gamEvolve.game.log', [])
.controller('LogCtrl', ($scope, gameHistory) ->
  $scope.text = "Hello!"
  $scope.aceLoaded = (editor) -> 
    editor.setReadOnly(true)

  # Format a message. Leave strings alone, and format other values as JSON
  messageToString = (message) ->
    messageParts = for value in message 
      if _.isString(value) then value else JSON.stringify(value) 
    return messageParts.join("  ")

  onUpdateGameHistory = () ->
    $scope.text = ""
    for index, frame of gameHistory.frames
      if frame.logMessages.length > 0
        $scope.text += "FRAME #{parseInt(index) + 1}:\n"
        for message in frame.logMessages
          $scope.text += "  #{message.level}: #{messageToString(message.message)}\n"

  # Bring gameHistory into scope so we can watch it
  $scope.gameHistory = gameHistory
  $scope.$watch("gameHistory", onUpdateGameHistory, true)
)
