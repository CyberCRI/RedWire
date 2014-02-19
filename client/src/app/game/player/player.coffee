# TODO: this should be configurable
GAME_DIMENSIONS = [960, 540]

buildLogMessages = (result) ->
  if not result.errors then return result.logMessages

  errorMessages = for error in result.errors
    { 
      path: error.path
      level: GE.logLevels.ERROR
      message: [error.stage, error.message] 
    }
  return errorMessages.concat(result.logMessages)

extendFrameResults = (result, memory, inputIoData) ->
  # Override memory, inputIoData, and log messages
  result.logMessages = buildLogMessages(result) 
  if memory? then result.memory = memory
  if inputIoData? then result.inputIoData = inputIoData 
  return result


angular.module('gamEvolve.game.player', [])
.controller "PlayerCtrl", ($scope, games, currentGame, gameHistory, gameTime, overlay) -> 
  # Globals
  puppetIsAlive = false
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
      console.error("Puppet reported error on operation #{message.operation}.", message.error)
    else
      console.log("Puppet reported success on operation #{message.operation}.", message)

    # TODO: handle errors in recording and update

    switch message.operation
      when "areYouAlive"
        if message.type is "error" then throw new Error("Cannot deal with areYouAlive error message")
        puppetIsAlive = true
        onUpdateCode() # Code might be already there 
      when "loadGameCode"
        if message.type is "error"
          $scope.$apply ->
            gameHistory.data.compilationErrors = [message.error]
            overlay.makeNotification("error")
            gameHistory.meta.version++
        else
          # The game loaded successfully
          $scope.$apply ->
            gameHistory.data.compilationErrors = []
            gameHistory.meta.version++

          if gameHistory.data.frames.length > 0 and gameHistory.data.frames[0].inputIoData
            # Notify the user
            overlay.makeNotification("updating", true)

            # If there are already frames, then update them 
            inputIoDataFrames = _.pluck(gameHistory.data.frames, "inputIoData")
            sendMessage("updateFrames", { memory: gameCode.memory, inputIoDataFrames })
          else
            # Else just record the first frame
            sendMessage("recordFrame", { memory: gameCode.memory })
      when "recordFrame"
        if message.type is "error" then throw new Error("Cannot deal with recordFrame error message")

        $scope.$apply ->
          # Set the first frame
          newFrame = extendFrameResults(message.value, gameCode.memory)

          if message.value.errors
            console.error("Record frames errors", message.value.errors)
            overlay.makeNotification("error")

          gameHistory.data.frames = [newFrame]
          gameHistory.meta.version++
          gameTime.currentFrameNumber = 0
      when "recording"
        if message.type isnt "error" then new Error("Cannot deal with recording success message")

        console.log("Recording met with error. Stopping it")
        $scope.$apply ->
          hadRecordingErrors = true # Used to notify the user 
          gameTime.isRecording = false
      when "stopRecording" 
        $scope.$apply ->
          metError = false

          # Remove frames after the current one
          gameHistory.data.frames.length = gameTime.currentFrameNumber + 1

          # Calculate memory going into the next frame
          lastFrame = gameHistory.data.frames[gameTime.currentFrameNumber]
          lastMemory = GE.applyPatches(lastFrame.memoryPatches, lastFrame.memory)

          # Add in the new results
          for results in message.value
            gameHistory.data.frames.push(extendFrameResults(results, lastMemory))
              
            if results.errors 
              console.error("Stop recording frames errors", results.errors)
              metError = true
              break

            # Calcuate the next memory to be used
            lastMemory = GE.applyPatches(results.memoryPatches, lastMemory)

          if metError 
            overlay.makeNotification("error")
          else
            overlay.clearNotification() # Clear "updating" status

          # Go the the last frame
          gameTime.currentFrameNumber = gameHistory.data.frames.length - 1

          # Update the version
          gameHistory.meta.version++
      when "updateFrames" 
        if message.type is "error" then throw new Error("Cannot deal with updateFrames error")

        $scope.$apply ->
          metError = false

          # Replace existing frames by the new results, until an error is found
          lastMemory = gameCode.memory
          for index, results of message.value
            # Copy over old inputIoData
            gameHistory.data.frames[index] = extendFrameResults(results, lastMemory, gameHistory.data.frames[index].inputIoData)

            if results.errors 
              console.error("Update frames errors", results.errors)
              metError = true
              break # Stop updating when error is found

            # Calcuate the next memory to be used
            lastMemory = GE.applyPatches(results.memoryPatches, lastMemory)

          if metError 
            overlay.makeNotification("error")
          else
            overlay.clearNotification() # Clear "updating" status

          # Update the version
          gameHistory.meta.version++
          # Display the current frame
          # TODO: go to the frame of first error
          onUpdateFrame(gameTime.currentFrameNumber)

  sendMessage = (operation, value) ->  
    # Note that we're sending the message to "*", rather than some specific origin. 
    # Sandboxed iframes which lack the 'allow-same-origin' header don't have an origin which you can target: you'll have to send to any origin, which might alow some esoteric attacks. 
    console.log("Sending #{operation} message to puppet");
    $('#gamePlayer')[0].contentWindow.postMessage({operation: operation, value: value}, '*')

  onUpdateCode = ->
    if not currentGame.version? then return
    if not puppetIsAlive then return

    gameCode = currentGame.version
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
    outputIoData = GE.applyPatches(frameResult.ioPatches, frameResult.inputIoData)
    sendMessage("playFrame", { outputIoData: outputIoData })
  $scope.$watch('gameTime.currentFrameNumber', onUpdateFrame, true)

  onUpdateRecording = (isRecording) ->
    if not gameCode? then return
    if isRecording 
      # Notify the user
      overlay.makeNotification("recording")

      # Start recording on next frame
      lastFrame = gameHistory.data.frames[gameTime.currentFrameNumber]
      nextMemory = GE.applyPatches(lastFrame.memoryPatches, lastFrame.memory)
      sendMessage("startRecording", { memory: nextMemory })
    else
      # Notify the user
      overlay.makeNotification("updating", true)

      sendMessage("stopRecording")
  $scope.$watch('gameTime.isRecording', onUpdateRecording, true)

  # Keep pinging puppet until he responds
  checkPuppetForSignsOfLife = -> 
    if puppetIsAlive then return # Will be set to true by message event listener

    sendMessage("areYouAlive")
    setTimeout(checkPuppetForSignsOfLife, 500)

  checkPuppetForSignsOfLife()

  # TODO: need some kind of notification from flexy-layout when a block changes size!
  # Until then automatically resize once in a while.
  resizeIntervalId = setInterval(onResize, 1000)
  $scope.$on("$destroy", -> clearInterval(resizeIntervalId))
