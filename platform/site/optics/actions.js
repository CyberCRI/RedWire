({
    clickListener: {
    paramDefs: {
      keyboard: { direction: "in" },
      mouse: { direction: "in" },
      constants: { direction: "in" },
      selected: { direction: "inout" },
      selectedPiece: { direction: "inout" },
      draggedPiece: { direction: "inout" },
      rotating: { direction: "inout", default: false },
      originalRotation: { direction: "inout" },
      originalPieceRotation: { direction: "inout" },
      pieces: { direction: "inout" },
      boxedPieces: { direction: "inout" },
      leftMouseDown: { direction: "inout", default: false },
      shapes: { direction: "out", default: "{}" }
    },    

    update: function() {
      //selects a square if it is on the board
      var that = this;

      function selectSquare(square, params) {
        if(that.tools.isInGrid(square, that.params.constants.gridSize)) {
          params.selected = {col: square[0], row: square[1]};
        }
      }

      //updates selected piece and dragged piece when the mouse button is pressed on a piece
      function mouseDownOnPiece(piecePressed, params) {
        if(piecePressed) {
          params.selectedPiece = null;
          params.rotating = false;
          params.originalRotation = null;
          params.originalPieceRotation = null;

          if(that.tools.isMovable(piecePressed, that.params.constants.unmovablePieces)) {
            params.draggedPiece = piecePressed;
          }
        }
      }

      var newLeftMouseDown = this.params.mouse.down && !this.params.leftMouseDown;
      var newLeftMouseReleased = !this.params.mouse.down && this.params.leftMouseDown;

      //copied from drawLight
      var selected = this.params.selected;

      //ROTATION: LOGIC (ANGLE COMPUTATION & SETTING)
      if(this.params.rotating && this.params.selectedPiece && this.params.mouse.position){
        if(this.params.originalPieceRotation === null) {
          //console.log("!!!this.params.originalRotation === null!!!");
          this.params.originalPieceRotation = this.params.selectedPiece.rotation;
        }
        //angle between axis Ox and axis Om where m is mouse position, O is piece center, and Ox is colinear to x-Axis
        var objectPosition = {};
        objectPosition.x = (this.params.selectedPiece.col + 0.5)*(this.params.constants.cellSize-1) + this.params.constants.upperLeftBoardMargin;
        objectPosition.y = (this.params.selectedPiece.row + 0.5)*(this.params.constants.cellSize-1) + this.params.constants.upperLeftBoardMargin;
        var hxPosition = this.params.mouse.position[0] - objectPosition.x;
        var hyPosition = this.params.mouse.position[1] - objectPosition.y;
        var omDistance = Math.sqrt(hxPosition*hxPosition + hyPosition*hyPosition);
        //var ohxDistance = hxPosition;
        var ohyDistance = -hyPosition;
        //var ratio = ohxDistance/omDistance;
        var ratio = ohyDistance/omDistance;
        var angle = 0;
        if(omDistance !== 0) {
          var absValueAngle = Math.acos(ratio)*180/Math.PI;
          if(hxPosition <= 0) {
            angle = -absValueAngle;
          } else {
            angle = absValueAngle;
          }
        }
        if(this.params.originalRotation === null) {
          //console.log("!!!this.params.originalRotation === null!!!");
          this.params.originalRotation = angle;
        }
        //console.log("objectPos="+coordinatesToString(objectPosition)
        //  +", mousePos="+coordinatesToString(this.params.mouse.position)
        //  +", omDist="+omDistance
        //  +", ohxDist="+ohxDistance
        //  +", ratio="+ratio
        //  +", angle="+angle);
        var piece = this.tools.findGridElement(
                                [this.params.selectedPiece.col, this.params.selectedPiece.row],
                                this.params.pieces
                              );
        var newRotation = angle-this.params.originalRotation+this.params.originalPieceRotation;
        //console.log("original rotation="+this.params.originalRotation+", angle="+angle+", new rotation="+newRotation);
        piece.rotation = newRotation % 360;
      }

      if(newLeftMouseDown || newLeftMouseReleased) {
        if(that.params.mouse.position)
        {
          //board coordinates
          var clickedColumn = this.tools.toBoardCoordinate(
            that.params.mouse.position[0], 
            this.params.constants.upperLeftBoardMargin, 
            this.params.constants.cellSize
            );
          var clickedRow = this.tools.toBoardCoordinate(
            that.params.mouse.position[1], 
            this.params.constants.upperLeftBoardMargin, 
            this.params.constants.cellSize
            );
          var boardCoordinates = [clickedColumn, clickedRow];

          //test whether there is a piece or not
          if (newLeftMouseDown)
          {
            //console.log(">>>>>>>>>> action.js: newLeftMouseDown, "+this.tools.paramsToString(this.params));

            //set mouse button flag
            this.params.leftMouseDown = true;

            //check whether the click happened on the board or not
            if(!this.tools.isInGrid(boardCoordinates, this.params.constants.gridSize)){
              //console.log("clicked outside of board");
              var boxIndex = this.tools.getIndexInBox(
                    [that.params.mouse.position[0], that.params.mouse.position[1]],
                    this.params.constants.boxLeft,
                    this.params.constants.boxTop,
                    this.params.constants.boxCellSize,
                    this.params.constants.boxRowsCount,
                    this.params.constants.boxColumnsCount
                  );
              //check whether the click happened in the box or not
              if(boxIndex !== null) {
                //console.log("clicked in box");
                //clicked in box
                var boxedPiece = this.params.boxedPieces[boxIndex];
                var pieceType = null;
                if(boxedPiece) {
                  pieceType = boxedPiece.type;
                  //console.log("clicked in box at position "+boxIndex+" on piece of type \""+pieceType+"\"");
                  mouseDownOnPiece(boxedPiece, this.params);
                } else if (this.params.selectedPiece != null) {
                  //console.log("clicked in box at position "+boxIndex+" on no piece, will try to put selected piece "+pieceToString(this.params.selectedPiece));

                  //uncomment this line to enable move by simple clic
                  //putPieceIntoBox(this.params.selectedPiece, this.params.pieces, this.params.boxedPieces);
                  this.params.selectedPiece = null;
                  this.params.rotating = false;
                  this.params.originalRotation = null;
                  this.params.originalPieceRotation = null;
                } else {
                  //console.log("clicked in box at position "+boxIndex+" on no piece, nothing to be done");
                }
                //console.log("<<<<<<<<<< finished click in box, "+this.tools.paramsToString(this.params));
              } // else clicked outsite of the box, out of the board: nothing to be done
            } else { //clicked on board
              //let's select the square that has been clicked on
              //console.log("clicked on board");
              var pieceClickedOn = this.tools.findGridElement(boardCoordinates, this.params.pieces);
              //check whether tries to rotate piece

              if(this.params.selectedPiece) {
                var selectedPiecePosition = {};
                selectedPiecePosition.x = this.tools.toPixelCoordinate(
                                            this.params.selectedPiece.col,
                                            this.params.constants.upperLeftBoardMargin,
                                            this.params.constants.cellSize
                                          );
                selectedPiecePosition.y = this.tools.toPixelCoordinate(
                                            this.params.selectedPiece.row,
                                            this.params.constants.upperLeftBoardMargin,
                                            this.params.constants.cellSize
                                          );
                //console.log("clicked close: selectedPiecePosition="+coordinatesToString(selectedPiecePosition)+", this.params.mouse.position="+coordinatesToString(this.params.mouse.position));
                if((this.tools.distance(this.params.mouse.position, selectedPiecePosition) < this.params.constants.cellSize*1.2)
                 &&(this.tools.distance(this.params.mouse.position, selectedPiecePosition) > this.params.constants.cellSize*0.7))
                {
                  this.params.rotating = true;
                  var rotatedPiece = this.tools.findGridElement(
                                                  [this.params.selectedPiece.col, this.params.selectedPiece.row],
                                                  this.params.pieces
                                                );
                  this.params.originalPieceRotation = 0;
                  if(rotatedPiece) this.params.originalPieceRotation = rotatedPiece.rotation;
                  //console.log("this.params.rotating = true; this.params.originalPieceRotation = "+this.params.originalPieceRotation);
                } else {
                  mouseDownOnPiece(pieceClickedOn, this.params);
                  selectSquare([clickedColumn, clickedRow], this.params);
                }
              } else {
                mouseDownOnPiece(pieceClickedOn, this.params);
                selectSquare([clickedColumn, clickedRow], this.params);
              }

              //console.log("<<<<<<<<<<<< finished click on board, "+this.tools.paramsToString(this.params));
            }

          } else if (newLeftMouseReleased) {
            //console.log(">>>>>>>>>>>>>> action.js: newLeftMouseReleased, "+this.tools.paramsToString(this.params));
            
            //reset mouse button flag
            this.params.leftMouseDown = false;

            if(!this.tools.isInGrid(boardCoordinates, this.params.constants.gridSize)){
              //put out of board: put piece in box
              //console.log("released outside of board");
              var boxIndex = this.tools.getIndexInBox(
                    [that.params.mouse.position[0], that.params.mouse.position[1]],
                    this.params.constants.boxLeft,
                    this.params.constants.boxTop,
                    this.params.constants.boxCellSize,
                    this.params.constants.boxRowsCount,
                    this.params.constants.boxColumnsCount
                  );
              //check whether the click happened in the box or not
              if(boxIndex !== null) {
                //console.log("clicked in box");
                //clicked in box
                var boxedPiece = this.params.boxedPieces[boxIndex];
                var pieceType = null;
                if(boxedPiece !== undefined) { //there was a piece
                  //uncomment this line to enable move by simple clic
                  //this.params.selectedPiece = boxedPiece;
                  this.params.draggedPiece = null;
                } else {
                  //console.log("action.js: put out of board: put piece in box");
                  if(this.params.selectedPiece) {
                    //console.log("action.js: this.params.selectedPiece");
                    //uncomment this line to enable move by simple clic
                    //putPieceIntoBox(that.params.selectedPiece, this.params.pieces, this.params.boxedPieces);
                    //this.params.draggedPiece = null;
                    //this.params.selectedPiece = null;
                  } else if(this.params.draggedPiece) {
                    //console.log("action.js: this.params.draggedPiece");
        
                    var put = this.tools.putPieceIntoBox(that.params.draggedPiece, this.params.pieces, this.params.boxedPieces);

                    this.params.pieces = put.pieces;
                    this.params.boxedPieces = put.boxedPieces;

                    this.params.draggedPiece = null;
                    this.params.selectedPiece = null;
                    this.params.rotating = false;
                    this.params.originalRotation = null;
                    this.params.originalPieceRotation = null;
                  } else {
                    //console.log("action.js: nothing to put in box");
                  }
                }
              } else {
                //console.log("released outside of board, outside of box");

                var put = this.tools.putPieceIntoBox(that.params.draggedPiece, this.params.pieces, this.params.boxedPieces);

                this.params.pieces = put.pieces;
                this.params.boxedPieces = put.boxedPieces;

                this.params.draggedPiece = null;
                this.params.selectedPiece = null;
                this.params.rotating = false;
                this.params.originalRotation = null;
                this.params.originalPieceRotation = null;
              }
            } else {
              //put on board: check if square is empty, then move piece
              //console.log("action.js: put on board: check if square is empty, then move piece");

              //let's select the square that has been clicked on
              //selectSquare([clickedColumn, clickedRow], this.params.selected);

              //test whether there is a piece or not
              //console.log("1");
              var pieceReleasedOn = this.tools.findGridElement(boardCoordinates, this.params.pieces);
              //console.log("2");
              if (pieceReleasedOn) {
                //console.log("action.js: released on piece of type \""+pieceReleasedOn.type+"\"");
                //console.log("action.js: drag and drop fails: undrag piece");

                if(this.params.draggedPiece &&  (this.params.draggedPiece.col == boardCoordinates[0]) && (this.params.draggedPiece.row == boardCoordinates[1])) {
                  //console.log("released on same piece, select");
                  this.params.selectedPiece = pieceReleasedOn;
                  //this.params.originalRotation = pieceReleasedOn.rotation;
                }
                else if(!this.params.draggedPiece && !this.params.selectedPiece) {
                  //console.log("released on piece, was neither selected nor dragged, select");
                  this.params.selectedPiece = pieceReleasedOn;
                  //this.params.originalRotation = pieceReleasedOn.rotation;
                } else {
                  //console.log("default, unselect");
                  this.params.selectedPiece = null;
                  this.params.rotating = false;
                  this.params.originalRotation = null;
                  this.params.originalPieceRotation = null;
                }
                this.params.draggedPiece = null;

               //console.log("<<<<<<<<<<< finished released on piece, "+this.tools.paramsToString(this.params)); 
              } else {
                //console.log("released on free square");
                if(this.params.selectedPiece) {
                  if(this.params.rotating) {
                    this.params.rotating = false;
                    this.params.originalRotation = null;
                    this.params.originalPieceRotation = null;
                  } else {
                    //console.log("action.js: position piece on ["+clickedColumn+","+clickedRow+"] if one was selected");
                    //uncomment this line to enable move by simple clic
                    //cf other call of movePieceTo: movePieceTo(this.params.selectedPiece, [clickedColumn, clickedRow], this.params.pieces, this.params.boxedPieces);
                    this.params.selectedPiece = null;
                    this.params.rotating = false;
                    this.params.originalRotation = null;
                    this.params.originalPieceRotation = null;
                  }
                  //console.log("<<<<<<<<<<< selected, "+this.tools.paramsToString(this.params)); 
                } else if (this.params.draggedPiece) {
                  //console.log("action.js: position piece on ["+clickedColumn+","+clickedRow+"] if one was being dragged");
                  selectSquare([clickedColumn, clickedRow], this.params);

                  var move = this.tools.movePieceTo(
                              this.params.draggedPiece, 
                              [clickedColumn, clickedRow], 
                              this.params.pieces, 
                              this.params.boxedPieces,
                              this.params.constants.gridSize,
                              this.params.constants.unmovablePieces
                            );

                  _.extend(this.params, move)

                  //console.log("<<<<<<<<<<< dragged, "+this.tools.paramsToString(this.params)); 
                } else {
                  //console.log("<<<<<<<<<<< neither selected nor dragged, "+this.tools.paramsToString(this.params)); 
                }
              }
            }
          }
        }
      }
    }
  },

  doInParallel: { 
    doc: "Just to place children under it"
  },

  changeParameterThroughKeyboard: {
    paramDefs: {
      "parameter": { direction: "inout" },
      "keysDown": null,
      "keyMap": null // Keymap must be in a form like { "37": "-10", "39": 3, "41": "hello" }
    },
    update: function() {
      for(var keyCode in this.params.keyMap)
      {
        // is the key down?
        if(this.params.keysDown[keyCode])
        {
          // Parse value of keyMap
          var value = this.params.keyMap[keyCode];
          if(_.isString(value) && value.length > 0 && (value[0] == "+" || value[0] == "-")) 
          {
            // Treat it as a numerical difference
            this.params.parameter += Number(value);
          }
          else
          {
            this.params.parameter = value;
          }
          // only treat a single keycode
          break;
        }
      } 
    }
  },

  doInSequence: {
    paramDefs: {
      activeChild: { direction: "inout", default: 0 },
    },
    listActiveChildren: function() { return [this.params.activeChild]; },
    handleSignals: function() { 
      if(this.signals[this.params.activeChild] == GE.signals.DONE)
        this.params.activeChild++;

      if(this.params.activeChild > this.children.length - 1)
      {
        this.params.activeChild = 0;
        return GE.signals.DONE;
      }
    } 
  },

  doForSomeTime: {
    paramDefs: {
      time: null,
      timer: { direction: "inout" }
    },
    update: function() { 
      if(this.params.timer++ >= this.params.time) {
        this.params.timer = 0;
        return GE.signals.DONE;
      }
    }
  },

  doWhile: {
    paramDefs: {
      value: null
    },
    update: function() { 
      if(!this.params.value) return GE.signals.DONE;
    }
  },

  when: {
    paramDefs: {
      value: null
    },
    listActiveChildren: function() { 
      return this.tools.childByName(this.children, this.params.value);
    }
  },

  // Selects the first branch if the expression is truthy, else the second (if it exists)
  "if": {
    paramDefs: {
      value: null
    },
    listActiveChildren: function() { 
      return this.params.value ? [0] : this.children.length > 1 ? [1] : []; 
    }
  },

  sandwich: {
    paramDefs: {
      condition: null,
      started: { direction: "inout" }
    },
    listActiveChildren: function() { 
      if(!this.params.track)
      {
        if(!this.params.condition) {
          return [0];
        } else {
          this.params.track = true;
          return [1];
        }
      } else {
        if(this.params.condition) {
          return [1];
        } else {
          this.params.track = false;
          return [2];
        }
      }
    }
  },

  reactToMouse: {
    paramDefs: {
      "shape": null,
      "mousePosition": null,
      "mouseDown": null,
      "_state_": { direction: "inout" },
      "_dragStartPosition_": { direction: "inout" },
      "minimumDragDistance": { default: "5" }
    },
    listActiveChildren: function() { 
      // Implement a state machine
      if(!this.params["_state_"]) this.params["_state_"] = "none";

      switch(this.params["_state_"]) {
        case "none":
          if(this.params.mousePosition && this.tools.pointIntersectsShape(this.params.mousePosition, this.params.shape)) {
            this.params["_state_"] = "hover";
            this.log(GE.logLevels.INFO, "Entering hover mode. State = " + this.params["_state_"]);
          } 
          break;
        case "hover":
          if(!this.params.mousePosition || !this.tools.pointIntersectsShape(this.params.mousePosition, this.params.shape)) {
            this.params["_state_"] = "none";
            this.log(GE.logLevels.INFO, "Leaving hover mode")
          } else if(this.params.mouseDown) {
            this.params["_dragStartPosition_"] = this.params.mousePosition;
            this.params["_state_"] = "pressed";
            this.log(GE.logLevels.INFO, "Entering presed mode")
          }
          break;
        case "pressed":
          if(!this.params.mouseDown) {
            this.params["_state_"] = "hover";
            this.params["_dragStartPosition_"] = null;
            this.log(GE.logLevels.INFO, "Leaving pressed mode")
            return this.tools.childByName(this.children, "click");
          } else if(Vector.create(this.params["_dragStartPosition_"]).distanceFrom(Vector.create(this.params.mousePosition)) >= this.params.minimumDragDistance) {
            this.params["_state_"] = "drag";
            this.params["_dragStartPosition_"] = null;
            this.log(GE.logLevels.INFO, "Entering drag mode")
            return this.tools.childByName(this.children, "startDrag");
          }
          break;
        case "drag":
          if(!this.params.mouseDown) {
            this.params["_state_"] = "hover";
            this.params["_dragStartPosition_"] = null;
             this.log(GE.logLevels.INFO, "Leaving drag mode")
           return this.tools.childByName(this.children, "endDrag");
          }
          break;
        default:
          throw new Error("Unknown state '" + this.params["_state_"] + "'");
      }

      // if the child has not been returned already, use the current state
      return this.tools.childByName(this.children, this.params["_state_"]);      
    }
  }

});
