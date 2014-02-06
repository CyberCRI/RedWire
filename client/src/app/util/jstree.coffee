angular.module("gamEvolve.util.jstree", []).directive "jstree", (currentGame) ->

  dnd =
    drag_check: (data) ->
      # No dropping in processors or emitters
      if data.r.attr("rel") in ["processor", "emitter"] then return false 

      # TODO: allow adding nodes before and after, not just inside
      result =  
        after: false
        before: false
        inside: true
      return result

    drag_finish: (data) ->
      source = if "processor-id" of data.o.attributes
          processor: data.o.attributes["processor-id"].nodeValue
          params:
            in: {}
            out: {}
        else if "switch-id" of data.o.attributes
          switch: data.o.attributes["switch-id"].nodeValue
          params:
            in: {}
            out: {}
        else 
          throw new Error("Unknown element #{data.o} accepted for drag and drop")

      path = data.r.data("path")
      target = currentGame.getTreeNode(path)

      # If the target doesn't have children, it needs an empty list
      if not target.children? then target.children = [] 
      target.children.unshift source

  types = 
    switch:
      icon:
        image: "/assets/images/switch.png"
    processor:
      valid_children: [] # Leaves in the tree
      icon:
        image: "/assets/images/processor.png"
    emitter:
      valid_children: [] # Leaves in the tree
      icon:
        image: "/assets/images/emitter.png"
    splitter:
      icon:
        image: "/assets/images/splitter.png"

  restrict: "A"
  scope:
    jstree: "="

  link: (scope, element, attrs) ->

    scope.$watch "jstree", ->
      $(element).jstree
        json_data:
          data: scope.jstree
        dnd: dnd
        types: 
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

