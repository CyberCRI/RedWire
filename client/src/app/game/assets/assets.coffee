angular.module('gamEvolve.game.assets', [
  'ui.bootstrap'
  'omr.angularFileDnD'
  'xeditable'
])

.controller 'AssetsCtrl', ($scope, $modal, currentGame, dndHelper) ->
  # Get the actions object from the currentGame service, and keep it updated
  $scope.assets = null
  $scope.fileName = ""
  $scope.file = null

  $scope.dropdownIsOpen = false

  # Transform assets to array so we can loop over it easier
  copyFromGameToScope = -> 
    if currentGame.version?
      $scope.assets = ({ name: name, data: data } for name, data of currentGame.version.assets)

  # Bring currentGame into scope so we can watch it 
  $scope.currentGame = currentGame
  $scope.$watch("currentGame.localVersion", copyFromGameToScope, true)

  # Transform assets back to object so we can loop over it easier
  copyFromScopeToGame = -> 
    if $scope.assets == null then return 

    assetsAsObject = _.object(([asset.name, asset.data] for asset in $scope.assets))
    if _.isEqual(assetsAsObject, currentGame.version.assets) then return 

    currentGame.version.assets = assetsAsObject
    currentGame.updateLocalVersion()
  $scope.$watch("assets", copyFromScopeToGame, true)

  $scope.edit = (index) -> 
    splitUrl = RW.splitDataUrl($scope.assets[index].data)

    options =
      backdrop: true
      templateUrl: 'game/assets/assetEditDialog.tpl.html'
      controller: 'AssetEditDialogCtrl'
      size: "lg"
      resolve: 
        # This object will be provided to the dialog as a dependency, and serves to communicate between the two
        liaison: ->
          {
            assetData: atob(splitUrl.data)
            mimeType: splitUrl.mimeType
            done: (newAssetData) ->
              decodedAsset = btoa(newAssetData)
              $scope.assets[index].data = RW.combineDataUrl
                mimeType: splitUrl.mimeType
                base64: splitUrl.base64
                data: decodedAsset
              copyFromScopeToGame()
              dialog.close()
            cancel: ->
              dialog.close()
          }
    dialog = $modal.open(options)

  $scope.remove = (index) -> 
    $scope.assets.splice(index, 1)

  $scope.clone = (index) -> 
    existingNames = _.pluck($scope.assets, "name")
    newName = dndHelper.findNewName(existingNames, $scope.assets[index].name)
    newAsset = RW.cloneData($scope.assets[index])
    newAsset.name = newName
    $scope.assets.push(newAsset)

  $scope.addAssetOfType = (mimeType) ->
    dataUrl = RW.combineDataUrl
      mimeType: mimeType
      base64: true
      data: ""
    $scope.assets.push({ name: "", data: dataUrl })
    $scope.closeDropdown()
    copyFromScopeToGame()

  $scope.closeDropdown = ->
    $scope.dropdownIsOpen = false

  $scope.$watch "file", ->
    if $scope.fileName is "" then return 

    $scope.assets.push({ name: $scope.fileName, data: $scope.file })
    # Reset this so that the same filename dragged twice in a row will be taken into account
    $scope.fileName = ""  
    $scope.file = null

.controller 'AssetEditDialogCtrl', ($scope, liaison) ->
  # Need to put input/output data under an object
  $scope.exchange = 
    assetData: liaison.assetData

  $scope.mimeType = liaison.mimeType
  $scope.editingMode = switch liaison.mimeType
    when "text/html" then "html"
    when "application/javascript" then "javascript"
    when "applcation/json" then "json"
    when "text/css" then "css"
    else "text"

  $scope.done = -> liaison.done($scope.exchange.assetData)
  $scope.cancel = -> liaison.cancel()

.directive 'assetDrag', ($parse, dndHelper) ->
    restrict: 'A'
    link: (scope, element, attrs) ->
      el = element[0]
      parsedDrag = $parse(attrs.assetDrag)
      el.draggable = true

      el.addEventListener "dragstart", (e) ->
        e?.stopPropagation()
        e.dataTransfer.effectAllowed = 'copy'
        draggedData = dndHelper.makeDraggedData({ asset: parsedDrag(scope) })
        dndHelper.setDraggedData(draggedData)
        return false

      el.addEventListener "dragend", (e) ->
        e?.stopPropagation()
        return false;

.directive "assetDropzone", (currentGame, dndHelper, circuits, games) ->
  restrict: 'A',
  link: (scope, element, attrs) ->
    acceptDrop = (event) -> dndHelper.getDraggedData()?.asset?

    el = element[0]
    el.addEventListener "drop", (event) -> 
      if not acceptDrop(event) then return false

      event.preventDefault?() 
      event.stopPropogation?() 
      console.log("drop asset")

      draggedData = dndHelper.getDraggedData()
      if not dndHelper.dragIsFromSameWindow(draggedData)
        games.recordMix(dndHelper.getDraggedGameId(draggedData))
      
      currentGame.version.assets[draggedData.asset.name] = draggedData.asset.data
      currentGame.updateLocalVersion()

      return false
