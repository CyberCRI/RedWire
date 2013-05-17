({
    clickListener: {
    paramDefs: {
      graphics: null,
      keyboard: null,
      selected: null,
      selectedPiece: null,
      draggedPiece: null,
      rotating: false,
      originalRotation: null,
      originalPieceRotation: null,
      pieces: [],
      boxedPieces: [],
      mouse: null,
      leftMouseDown: false,
      constants: null
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
        console.log("mouseDownOnPiece(piecePressed="+that.tools.pieceToString(piecePressed)+", "+that.tools.paramsToString(params)+")");
        if(piecePressed) {
          console.log("action.js: clicked on piece of type \""+piecePressed.type+"\"");
          console.log("action.js: the previously selected piece is unselected");
          params.selectedPiece = null;
          console.log("rotating = false");
          params.rotating = false;
          params.originalRotation = null;
          params.originalPieceRotation = null;

          console.log("action.js: \""+piecePressed.type+"\" starts to be dragged, even if a piece was already being dragged");
          if(that.tools.isMovable(piecePressed, that.params.constants.unmovablePieces)) {
            params.draggedPiece = piecePressed;
          }
          console.log("finished mouseDownOnPiece(piecePressed="+that.tools.pieceToString(piecePressed)+", "+that.tools.paramsToString(params)+")");
        } else {
          console.log("finished mouseDownOnPiece(piecePressed="+that.tools.pieceToString(piecePressed)+", "+that.tools.paramsToString(params)+"), nothing done");
        }
      }

      var newLeftMouseDown = this.params.mouse.down && !this.params.leftMouseDown;
      var newLeftMouseReleased = !this.params.mouse.down && this.params.leftMouseDown;

      //copied from drawLight
      var that = this;
      var selected = this.params.selected;

      //DRAGGING: GRAPHICS (DRAGGED PIECE DRAWING)
      if(this.params.draggedPiece && this.params.mouse.position){
        GE.addUnique(this.params.graphics.shapes, {
          type: "image",
          layer: "drag",
          asset: this.params.draggedPiece.type,
          alpha: 0.5,
          position: [-this.params.constants.pieceAssetCentering, -this.params.constants.pieceAssetCentering],
          translation: [this.params.mouse.position.x, this.params.mouse.position.y],
          rotation: this.params.draggedPiece.rotation // In degrees 
        });
      }

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
        var hxPosition = this.params.mouse.position.x - objectPosition.x;
        var hyPosition = this.params.mouse.position.y - objectPosition.y;
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
            that.params.mouse.position.x, 
            this.params.constants.upperLeftBoardMargin, 
            this.params.constants.cellSize
            );
          var clickedRow = this.tools.toBoardCoordinate(
            that.params.mouse.position.y, 
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
                    [that.params.mouse.position.x, that.params.mouse.position.y],
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
                    [that.params.mouse.position.x, that.params.mouse.position.y],
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
                if(boxedPiece) { //there was a piece
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
                    //XXXmovePieceTo(this.params.selectedPiece, [clickedColumn, clickedRow], this.params.pieces, this.params.boxedPieces);
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

                  this.params.piece                 = move.piece;
                  this.params.pieces                = move.pieces;
                  this.params.boxedPieces           = move.boxedPieces;
                  this.params.selectedPiece         = move.selectedPiece;
                  this.params.draggedPiece          = move.draggedPiece;
                  this.params.rotating              = move.rotating;
                  this.params.originalRotation      = move.originalRotation;
                  this.params.originalPieceRotation = move.originalPieceRotation;

                  console.log("<<<<<<<<<<< dragged, "+this.tools.paramsToString(this.params)); 
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

  clearBackground: {
    paramDefs: {
      "color": "black",
      "graphics": null
    },
    update: function() {
      GE.addUnique(this.params.graphics.shapes, {
        type: "rectangle",
        layer: "bg",
        fillStyle: this.params.color,
        position: [0, 0],
        size: this.params.graphics.size
      });
    }
  },

  drawImage: {
    paramDefs: {
      graphics: null,
      image: null,
      layer: "",
      x: 0,
      y: 0
    },
    update: function() {
      GE.addUnique(this.params.graphics.shapes, {
        type: "image",
        layer: this.params.layer,
        asset: this.params.image,
        position: [this.params.x, this.params.y]
      });
    }
  },

  drawText: {
    paramDefs: {
      text: "",
      x: 0,
      y: 12,
      style: "black",
      font: "12px Arial",
      align: "left",
      "graphics": null
    },
    update: function() { 
      GE.addUnique(this.params.graphics.shapes, {
        type: "text",
        layer: "text",
        text: this.params.text,
        strokeStyle: this.params.style,
        fillStyle: this.params.style,
        font: this.params.font,
        align: this.params.align,
        position: [this.params.x, this.params.y]
      });
    }
  },

  group: { 
    doc: "Just to place children under it"
  },

  drawPiece: {
    paramDefs: {
      graphics: null,
      type: null,
      row: 0,
      col: 0,
      rotation: 0,
      constants: null,
      rotating: false,
      selectedPiece: null
    },

    update: function() {
      var that = this;

      function drawObject(layer, assetName, scale, assetSize, col, row, cellSize, upperLeftBoardMargin, rotation) {
        GE.addUnique(that.params.graphics.shapes, that.tools.getDrawableObject(layer, assetName, scale, assetSize, col, row, cellSize, upperLeftBoardMargin, rotation));
      }

      drawObject("pieces", that.params.type, 1, 50, that.params.col, that.params.row, that.params.constants.cellSize, that.params.constants.upperLeftBoardMargin, that.params.rotation);

      if(this.params.selectedPiece && this.params.selectedPiece.col != null && (this.params.selectedPiece.col == this.params.col) && (this.params.selectedPiece.row == this.params.row)){
        var assetImage = "can-rotate";
        if(this.params.rotating){
          assetImage = "is-rotating";
        }
        drawObject("rotating", assetImage, 0.5, 208, that.params.col, that.params.row, that.params.constants.cellSize, that.params.constants.upperLeftBoardMargin, that.params.rotation);
      }
    }
  },

  // draws a boxed piece in the box according to its index in the "boxedPiece" table
  drawBoxedPiece: {
    paramDefs: {
      graphics: null,
      type: null,
      index: 0,
      constants: null
    },
    update: function() {
      var boxPosition = [this.params.index % 2, this.params.index >> 1];
      GE.addUnique(this.params.graphics.shapes, {
        type: "image",
        layer: "pieces",
        asset: this.params.type,
        scale: 0.67,
        position: [-this.params.constants.pieceAssetCentering, -this.params.constants.pieceAssetCentering],
        translation: [this.params.constants.boxLeft + (boxPosition[0]+.5) * this.params.constants.boxCellSize[0], this.params.constants.boxTop + (boxPosition[1]+.5) * this.params.constants.boxCellSize[1]],
        rotation: 0 // In degrees 
      });
    }
  },

  drawSelected: {
    paramDefs: {
      graphics: null,
      row: 0,
      col: 0,
      constants: null
    },
    update: function() {
      GE.addUnique(this.params.graphics.shapes, {
        type: "rectangle",
        layer: "selection",
        position: [this.params.col * this.params.constants.cellSize + this.params.constants.upperLeftBoardMargin, 
        this.params.row * this.params.constants.cellSize + this.params.constants.upperLeftBoardMargin],
        size: [50, 50],
        strokeStyle: "yellow",
        lineWidth: 4
      });
    }
  },

  incrementNumber: {
    paramDefs: {
      number: 0
    },
    update: function() {
      this.params.number++;
    }
  },

  drawLight: {
    paramDefs: {
      graphics: null,
      pieces: [],
      constants: null,
      goalReached: false
    },
    update: function() {
      var EXTEND_LINES_FACTOR = Sylvester.precision;
      var that = this;
      var gridSize = that.params.constants.gridSize;

      function handleGridElement()
      {
        if(element.type == "wall")
        {
          // find intersection with wall
          var wallIntersection = that.tools.intersectsCell(lightSegments[lightSegments.length - 1].origin, lightDestination, [element.col, element.row], EXTEND_LINES_FACTOR);
          if(wallIntersection === null) throw new Error("Cannot find intersection with wall");
          lightSegments[lightSegments.length - 1].destination = wallIntersection;

          lightIntensity = 0;
        }
        else if(element.type == "mirror")
        {
          // find intersection with central line
          var rotation = element.rotation * Math.PI / 180; 
          var centralLineDiff = [.5 * Math.cos(rotation), .5 * Math.sin(rotation)];
          var centralLine = [[element.col + 0.5 + centralLineDiff[0], element.row + 0.5 + centralLineDiff[1]], [element.col + 0.5 - centralLineDiff[0], element.row + 0.5 - centralLineDiff[1]]];
          if(intersection = this.tools.findIntersection(lightSegments[lightSegments.length - 1].origin, lightDestination, [centralLine], EXTEND_LINES_FACTOR))
          {
            lightSegments[lightSegments.length - 1].destination = intersection;

            lightIntensity *= that.params.constants.mirrorAttenuationFactor;
            if(lightIntensity < that.params.constants.minimumAttenuation)
            {
              lightIntensity = 0;
            }
            else
            {
              lightSegments.push({ origin: intersection, intensity: lightIntensity });

              // reflect around normal
              // normal caluclation from http://www.gamedev.net/topic/510581-2d-reflection/)
              // reflection calculation from http://paulbourke.net/geometry/reflected/ 
              // Rr = Ri - 2 N (Ri . N)
              var normal = Vector.create([-Math.sin(rotation), Math.cos(rotation)]);
              var oldLightDirection = Vector.create(lightDirection);
              lightDirection = oldLightDirection.subtract(normal.multiply(2 * oldLightDirection.dot(normal))).elements;
 
              lightDirectionUpdated();
            }
          }
        }
        else if(element.type == "squarePrism")
        {
          that.params.goalReached = true;
        }
      }

      function lightDirectionUpdated()
      {
        lightSigns = [lightDirection[0] > 0 ? 1 : -1, lightDirection[1] > 0 ? 1 : -1];

        var distanceOutOfGrid = Math.sqrt(gridSize[0]*gridSize[0] + gridSize[1]*gridSize[1]);
        var lastOrigin = lightSegments[lightSegments.length - 1].origin;
        lightDestination = Sylvester.Vector.create(lastOrigin).add(Sylvester.Vector.create(lightDirection).multiply(distanceOutOfGrid)).elements.slice();

      }

      // all lines are in grid space, not in screen space
      // options override default values for all drawn shapes (layer, composition, etc.)
      function drawGradientLine(origin, dest, innerRadius, outerRadius, colorRgba, options)
      {
        var marginV = Vector.create([that.params.constants.toSquareCenterOffset, that.params.constants.toSquareCenterOffset]);

        // find normal to line (http://stackoverflow.com/questions/1243614/how-do-i-calculate-the-normal-vector-of-a-line-segment)
        var originV = Vector.create(origin).multiply(that.params.constants.cellSize).add(marginV);
        var destV = Vector.create(dest).multiply(that.params.constants.cellSize).add(marginV);
        var d = destV.subtract(originV);
        var normal = Vector.create([-d.elements[1], d.elements[0]]).toUnitVector();

        var strokeGradUpper = originV.add(normal.multiply(outerRadius));
        var strokeGradLower = originV.add(normal.multiply(-outerRadius));

        var transRgba = _.clone(colorRgba);
        transRgba[3] = 0;

        strokeGrad = {
          type: "linearGradient",
          startPosition: strokeGradUpper.elements,
          endPosition: strokeGradLower.elements,
          colorStops: [
            { position: 0, color: "rgba(" + transRgba.join(",") + ")" },
            { position: innerRadius / outerRadius, color: "rgba(" + colorRgba.join(",") + ")" },
            { position: 1 - innerRadius / outerRadius, color: "rgba(" + colorRgba.join(",") + ")" },
            { position: 1, color: "rgba(" + transRgba.join(",") + ")" }
          ]
        };

        GE.addUnique(that.params.graphics.shapes, _.extend({
          type: "path",
          layer: "light",
          strokeStyle: strokeGrad,
          lineWidth: 2 * outerRadius,
          points: [originV.elements, destV.elements]
        }, options));

        fillGrad = {
          type: "radialGradient",
          start: {
            position: originV.elements,
            radius: 0
          },
          end: {
            position: originV.elements,
            radius: outerRadius
          },
          colorStops: [
            { position: innerRadius / outerRadius, color: "rgba(" + colorRgba.join(",") + ")" },
            { position: 1, color: "rgba(" + transRgba.join(",") + ")" }
          ]
        };

        GE.addUnique(that.params.graphics.shapes, _.extend({
          type: "circle",
          layer: "light",
          fillStyle: fillGrad,
          position: originV.elements,
          radius: outerRadius
        }, options));

        fillGrad = {
          type: "radialGradient",
          start: {
            position: destV.elements,
            radius: 0
          },
          end: {
            position: destV.elements,
            radius: outerRadius
          },
          colorStops: [
            { position: innerRadius / outerRadius, color: "rgba(" + colorRgba.join(",") + ")" },
            { position: 1, color: "rgba(" + transRgba.join(",") + ")" }
          ]
        };

        GE.addUnique(that.params.graphics.shapes, _.extend({
          type: "circle",
          layer: "light",
          fillStyle: fillGrad,
          position: destV.elements,
          radius: outerRadius
        }, options));
      }

      // Do everything in the "grid space" and change to graphic coordinates at the end

      // find source of light
      // TODO: this could be replacd by a WHERE bind expression
      var lightSource;
      for(var i in this.params.pieces)
      {
        var piece = this.params.pieces[i];
        if(piece.type == "laser-on") 
        {
          lightSource = piece;
          break;
        }
      }
      if(!lightSource) {
        return;
      }

      // calculate origin coordinates of light 
      // the piece starts vertically, so we rotate it 90 degrees clockwise by default
      var rotation = (lightSource.rotation - 90) * Math.PI / 180; 
      var lightDirection = [Math.cos(rotation), Math.sin(rotation)];
      // TODO: add color portions of light (3 different intensities)
      var lightIntensity = 1.0; // start at full itensity

      // follow light path through the grid, checking for intersections with pieces
      // Based on Bresenham's "simplified" line algorithm (http://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm)      
      var currentCell = [lightSource.col, lightSource.row]
      var lightSegments = [ { origin: [currentCell[0] + 0.5, currentCell[1] + 0.5], intensity: lightIntensity }];

      var lightSigns;
      var lightDestination; // represents a point outside of the grid that the light could reach if unimpeded 
      lightDirectionUpdated();

      var element;
      var nextCells = [];
      do
      { 
        var verticalIntersection = null;
        if(Math.abs(lightDirection[0]) > Sylvester.precision)
        {
          var x = currentCell[0] + (lightDirection[0] > 0 ? 1 : 0);
          var line = [[x, currentCell[1]], [x, currentCell[1] + 1]];
          verticalIntersection = this.tools.findIntersection(lightSegments[lightSegments.length - 1].origin, lightDestination, [line], EXTEND_LINES_FACTOR);
        } 
        var horizontalIntersection = null;
        if(Math.abs(lightDirection[1]) > Sylvester.precision)
        {
          var y = currentCell[1] + (lightDirection[1] > 0 ? 1 : 0);
          var line = [[currentCell[0], y], [currentCell[0] + 1, y]]
          horizontalIntersection = this.tools.findIntersection(lightSegments[lightSegments.length - 1].origin, lightDestination, [line], EXTEND_LINES_FACTOR);
        } 

        if(verticalIntersection && horizontalIntersection)
        {
          // move diagonally
          currentCell = [currentCell[0] + lightSigns[0], currentCell[1] + lightSigns[1]];
        }
        else if(verticalIntersection)
        {
          // move horizontally
          currentCell = [currentCell[0] + lightSigns[0], currentCell[1]];          
        }
        else if(horizontalIntersection)
        {
          // move vertically
          currentCell = [currentCell[0], currentCell[1] + lightSigns[1]];          
        }
        else 
        {
          // this is WEIRD!
          throw new Error("Light vector is NULL");
        }

        if(!this.tools.isInGrid(currentCell, this.params.constants.gridSize))
        {
          lightIntensity = 0;

          // find intersection with boundaries
          var boundaryIntersection = this.tools.intersectsBoundaries(lightSegments[lightSegments.length - 1].origin, lightDestination, gridSize, EXTEND_LINES_FACTOR);
          if(boundaryIntersection === null) throw new Error("Cannot find intersection with boundaries");
          lightSegments[lightSegments.length - 1].destination = boundaryIntersection;
        }
        else if(element = this.tools.findGridElement(currentCell, this.params.pieces))
        {
          handleGridElement();
        }
      } while(lightIntensity > 0);

      // DRAW SEGMENTS

      // Draw black mask that we will cut away from
      // based on the method of this fiddle: http://jsfiddle.net/wNYkX/3/
      GE.addUnique(this.params.graphics.shapes, {
        type: "rectangle",
        layer: "mask",
        fillStyle: "black",
        position: this.params.constants.playableBoardOffset,
        size: this.params.constants.playableBoardSize,
        order: 0
      });

      // now cut away, using 'destination-out' composition
      var maskOptions = { 
        layer: "mask", 
        composition: "destination-out", 
        order: 1 
      };
      for(var i = 0; i < lightSegments.length; i++)
      {
        //TODO extract 30 and 40 values
        drawGradientLine(lightSegments[i].origin, lightSegments[i].destination, 30, 40, [255, 255, 255, lightSegments[i].intensity], maskOptions);
      }

      // draw light ray normally
      for(var i = 0; i < lightSegments.length; i++)
      {
        //TODO extract 4 and 6 values
        drawGradientLine(lightSegments[i].origin, lightSegments[i].destination, 4, 6, [255, 0, 0, lightSegments[i].intensity]);
      }
    }
  },

  rotateSelectedPiece: {
    paramDefs: {
      "selected": null,
      "pieces": [],
      "keyboard": null,
      "constants": null
    },
    update: function() {
      /*
      var selectedPiece = this.tools.findGridElement(
                            [this.params.selected.col, this.params.selected.row],
                            this.params.pieces
                          );
      if(!selectedPiece || !this.tools.isRotatable(selectedPiece, this.params.constants.unrotatablePieces)) return; // nothing selected, so can't rotate

      var keysDown = this.params.keyboard.keysDown; // alias
      //if(keysDown[37]) { // left
      //  selectedPiece.rotation -= this.params.constants.rotationAmount;
      //} else if(keysDown[39]) { // right
      //  selectedPiece.rotation += this.params.constants.rotationAmount;
      //}
      */
    }
  },

  doInSequence: {
    paramDefs: {
      activeChild: 0,
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
      timer: 0,
      time: 0
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
      a: 0,
      b: 0
    },
    update: function() { 
      if(this.params.a !== this.params.b) return GE.signals.DONE;
    }
  },

  drawCursors: {
    paramDefs: {
      "pieces": [],
      "boxedPieces": [],
      "mouse": null,
      "constants": {},
      "draggedPiece": null
    },
    update: function() {
      if(!this.params.mouse.position) {
        return;
      } else {
      }

      if(this.params.draggedPiece) {
        this.params.mouse.cursor = "move";
      }
      else
      {
        var mousePos = [this.params.mouse.position.x, this.params.mouse.position.y];
        var gridCell = [this.tools.toBoardCoordinate(
                          mousePos[0], 
                          this.params.constants.upperLeftBoardMargin, 
                          this.params.constants.cellSize), 
                        this.tools.toBoardCoordinate(
                          mousePos[1],
                          this.params.constants.upperLeftBoardMargin,
                          this.params.constants.cellSize
                          )
                        ];
        if(this.tools.findGridElement(gridCell, this.params.pieces) 
            ||  this.tools.getBoxedPiece(
                  this.tools.getIndexInBox(
                    mousePos,
                    this.params.constants.boxLeft,
                    this.params.constants.boxTop,
                    this.params.constants.boxCellSize,
                    this.params.constants.boxRowsCount,
                    this.params.constants.boxColumnsCount
                  ),
                  this.params.boxedPieces
                )
          )
        {
          this.params.mouse.cursor = "pointer";
        }
      }
    }
  }
});