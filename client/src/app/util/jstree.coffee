angular.module("gamEvolve.util.jstree", []).directive "jstree", (currentGame) ->

  dnd =
    drag_check: (data) ->
      # No dropping in processors
      return false if data.r.attr("rel") is "processor"
      # For simplicity's sake, DnD is allowed only for adding processors INSIDE tree nodes
      after: false
      before: false
      inside: true

    drag_finish: (data) ->
      processorId = data.o.attributes["processor-id"].nodeValue
      path = data.r.data("path")
      target = currentGame.getTreeNode(path)
      source =
        processor: processorId
        params:
          in: {}
          out: {}
      target.children.unshift source

  types = types:
    switch:
      icon:
        image: "/assets/images/switch.png"
    processor:
      valid_children: [] # Processors are leafs in the tree


  restrict: "A"
  scope:
    jstree: "="

  link: (scope, element, attrs) ->

    scope.$watch "jstree", ->
      $(element).jstree
        json_data:
          data: scope.jstree
        dnd: dnd
        types: types
        core:
          html_titles: true
        plugins: ["themes", "ui", "json_data", "dnd", "types", "wholerow", "crrm"]

    emitEditEvent = (path) ->
      scope.$emit "editChipButtonClick", JSON.parse(path)

    $(element).on "click", "a[editChip]", (eventObject) ->
      clicked = $(eventObject.target)
      if clicked.attr("editChip")
        emitEditEvent clicked.attr("editChip")
      else
        emitEditEvent $(clicked.parent()[0]).attr("editChip")

    emitRemoveEvent = (path) ->
      scope.$emit "removeChipButtonClick", JSON.parse(path)

    $(element).on "click", "a[removeChip]", (eventObject) ->
      clicked = $(eventObject.target)
      if clicked.attr("removeChip")
        emitRemoveEvent clicked.attr("removeChip")
      else
        emitRemoveEvent $(clicked.parent()[0]).attr("removeChip")

