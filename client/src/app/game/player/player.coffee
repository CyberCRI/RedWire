# TODO: this should be configurable
GAME_DIMENSIONS = [960, 540]

angular.module('gamEvolve.game.player', [])
.controller "PlayerCtrl", ($scope, games, currentGame, gameHistory, gameTime) -> 
  # Globals
  gameCode = null
  oldRoundedScale = null

  # Bring services into the scope
  $scope.currentGame = currentGame
  $scope.gameTime = gameTime

  # TODO: take out this "global" message handler?
  window.addEventListener 'message', (e) -> 
    # Sandboxed iframes which lack the 'allow-same-origin' header have "null" rather than a valid origin. 
    if e.origin isnt "null" or e.source isnt $("#gamePlayer")[0].contentWindow then return

    message = e.data

    if message.type is "error"
      console.error("Puppet reported error", message.error)
    else
      console.log("Puppet reported success", message)

    # TODO: handle errors in recording and update

    switch message.operation
      when "loadGameCode"
        # Once the game is loaded
        if gameHistory.data.frames.length > 0
          # If there are already frames, then update them 
          inputServiceDataFrames = _.pluck(gameHistory.data.frames, "inputServiceData")
          sendMessage("updateFrames", { model: gameHistory.data.frames[0].model, inputServiceDataFrames })
        else
          # Else just record the first frame
          sendMessage("recordFrame", { model: gameCode.model })
      when "recordFrame"
        # Set the first frame
        $scope.$apply ->
          newFrame = 
            model: gameCode.model # Initial model
            inputServiceData: message.value.inputServiceData 
            servicePatches: message.value.servicePatches
            logMessages: message.value.logMessages 
          gameHistory.data.frames = [newFrame]
          gameHistory.meta.version++
          gameTime.currentFrameNumber = 0
      when "stopRecording" 
        $scope.$apply ->
          # Remove frames after the current one
          gameHistory.data.frames.length = gameTime.currentFrameNumber + 1

           # Replace the service data on the last frame
          results = message.value[0]
          gameHistory.data.frames[gameTime.currentFrameNumber].inputServiceData = results.inputServiceData
          gameHistory.data.frames[gameTime.currentFrameNumber].servicePatches = results.servicePatches
          gameHistory.data.frames[gameTime.currentFrameNumber].logMessages = results.logMessages

          # Add in the new results
          lastModel = gameHistory.data.frames[gameTime.currentFrameNumber].model
          for results in message.value[1..]
            gameHistory.data.frames.push
              model: lastModel
              servicePatches: results.servicePatches
              inputServiceData: results.inputServiceData
              logMessages: results.logMessages
            # Calcuate the next model to be used
            lastModel = GE.applyPatches(results.modelPatches, lastModel)

          # Go the the last frame
          gameTime.currentFrameNumber = gameHistory.data.frames.length - 1

          # Update the version
          gameHistory.meta.version++
      when "updateFrames" 
        $scope.$apply ->
          # Replace existing frames by the new results
          lastModel = gameHistory.data.frames[0].model
          for index, results of message.value
            gameHistory.data.frames[index] = 
              model: lastModel
              servicePatches: results.servicePatches
              inputServiceData: results.inputServiceData
              logMessages: results.logMessages
            # Calcuate the next model to be used
            lastModel = GE.applyPatches(results.modelPatches, lastModel)

            # Update the version
          gameHistory.meta.version++

          # Display the current frame
          onUpdateFrame(gameTime.currentFrameNumber)

  sendMessage = (operation, value) ->  
    # Note that we're sending the message to "*", rather than some specific origin. 
    # Sandboxed iframes which lack the 'allow-same-origin' header don't have an origin which you can target: you'll have to send to any origin, which might alow some esoteric attacks. 
    $('#gamePlayer')[0].contentWindow.postMessage({operation: operation, value: value}, '*')

  onUpdateCode = (code) ->
    if not code? then return

    gameCode = code
    console.log("Game code changed to", gameCode)
    sendMessage("loadGameCode", gameCode)
  $scope.$watch('currentGame.version', onUpdateCode, true)

  onResize = -> 
    screenElement = $('#gamePlayer')
    scale = Math.min(screenElement.parent().outerWidth() / GAME_DIMENSIONS[0], screenElement.parent().outerHeight() / GAME_DIMENSIONS[1])
    roundedScale = scale.toFixed(2)
    # Avoid rescaling if not needed
    if oldRoundedScale is roundedScale then return 

    oldRoundedScale = roundedScale
    newSize = [
      roundedScale * GAME_DIMENSIONS[0]
      roundedScale * GAME_DIMENSIONS[1]
    ]
    remainingSpace = [
      screenElement.parent().outerWidth() - newSize[0]
      screenElement.parent().outerHeight() - newSize[1]
    ]
    screenElement.css 
      "width": "#{newSize[0]}px"
      "height": "#{newSize[1]}px"
      "left": "#{remainingSpace[0] / 2}px"
      "top": "#{remainingSpace[1] / 2}px"
    sendMessage("changeScale", roundedScale)

  onUpdateFrame = (frameNumber) ->
    if not gameCode? then return
    frameResult = gameHistory.data.frames[frameNumber]
    outputServiceData = GE.applyPatches(frameResult.servicePatches, frameResult.inputServiceData)
    sendMessage("playFrame", { outputServiceData: outputServiceData })
  $scope.$watch('gameTime.currentFrameNumber', onUpdateFrame, true)

  onUpdateRecording = (isRecording) ->
    if not gameCode? then return
    if isRecording 
      sendMessage("startRecording", { model: gameHistory.data.frames[gameTime.currentFrameNumber].model })
    else
      sendMessage("stopRecording")
  $scope.$watch('gameTime.isRecording', onUpdateRecording, true)

  # TODO: need some kind of notification from flexy-layout when a block changes size!
  # Until then automatically resize once in a while.
  setInterval(onResize, 1000)
