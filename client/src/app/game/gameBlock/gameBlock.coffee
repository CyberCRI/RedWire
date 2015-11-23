angular.module('gamEvolve.game.block', [])
  .directive("gameBlock", ->
    return {
      restrict: "E"
      scope:
        game: "=" 
      templateUrl: 'game/gameBlock/gameBlock.tpl.html'
      controller: ($scope) ->
        $scope.formatDate = (date) -> moment(date).fromNow()
      link: (scope, element, attrs) ->
        staticImage = "url(#{scope.game.screenshot or '/assets/images/screenshot_standin.png'})" 
        animatedImage = "url(#{scope.game.animation or '/assets/images/screenshot_standin.png'})" 

        # Default to static image
        element.find(".screenshot").css("background-image", staticImage)
        
        element.on "mouseenter", ->
          element.find(".screenshot").css("background-image", animatedImage)
        element.on "mouseleave", ->
          element.find(".screenshot").css("background-image", staticImage)
    }
  )
  .directive("gameBlockPanel", ->
    return {
      restrict: "E"
      scope:
        title: "="
        games: "=" 
      templateUrl: 'game/gameBlock/gameBlockPanel.tpl.html'
      controller: ($scope) ->
        updateRows = ->
          # Split the games into rows of 3
          $scope.rows = []
          currentRow = []
          for index, game of $scope.games 
            currentRow.push(game)

            # Make a new row if needed
            if index % 3 is 2
              $scope.rows.push(currentRow)
              currentRow = []

          # Add last row if needed
          if currentRow.length > 0        
              $scope.rows.push(currentRow)

        $scope.$watch("games", updateRows)
     }
   )
  .directive("gameBlockPanelPaged", ->
    return {
      restrict: "E"
      scope:
        title: "="
        gamesPerPage: "="
        getPageOfGames: "=" # function that takes parameter "page" starting at 0 and "gamesPerPage" and returns promise for list of games
        countGames: "=" # function that takes no parameters and returns promise for the total number of games
      templateUrl: 'game/gameBlock/gameBlockPanelPaged.tpl.html'
      controller: ($scope) ->
        updateRows = ->
          # Split the games into rows of 3
          $scope.rows = []
          currentRow = []
          for index, game of $scope.games 
            currentRow.push(game)

            # Make a new row if needed
            if index % 3 is 2
              $scope.rows.push(currentRow)
              currentRow = []

          # Add last row if needed
          if currentRow.length > 0        
              $scope.rows.push(currentRow)

        updateGames = (games) ->
          $scope.games = games
          updateRows()
          $scope.isLoading = false

        lastSortBy = null
        lastPageNumber = null
        loadPage = ->
          if lastSortBy is $scope.sortBy and lastPageNumber is $scope.pageNumber then return

          lastSortBy = $scope.sortBy
          lastPageNumber = $scope.pageNumber

          $scope.isLoading = true

          $scope.getPageOfGames($scope.pageNumber - 1, $scope.gamesPerPage, $scope.sortBy)
          .then(updateGames)

        changeSortBy = ->
          # Load first page again
          $scope.pageNumber = 1
          loadPage()

        # Set default values
        $scope.pageNumber = 1
        $scope.sortBy = "latest"

        # Count games 
        $scope.countGames()
        .then((gameCount) -> $scope.gameCount = gameCount)

        $scope.$watch("pageNumber", loadPage)
        $scope.$watch("sortBy", changeSortBy)
     }
   )

