({
  //converts a pixel coordinate to a board coordinate
  //assumes that the board is made out of squares
  toBoardCoordinate: function(pixelCoordinate)
  {
    var res = Math.floor((pixelCoordinate - that.params.constants.upperLeftBoardMargin)/that.params.constants.cellSize);
    //console.log("toBoardCoordinates("+pixelCoordinate+")="+res+" with upperLeftBoardMargin="+that.params.constants.upperLeftBoardMargin+", pieceAssetCentering="+that.params.constants.pieceAssetCentering+", cellSize="+that.params.constants.cellSize);
    return res;
  },

  toPixelCoordinate: function(boardCoordinate)
  {
    return (boardCoordinate + 0.5)*(that.params.constants.cellSize-1) + that.params.constants.upperLeftBoardMargin;
  },

  //copied from drawLight
  findGridElement: function(square, pieces)
  {
    //console.log("findGridElement(square="+coordinatesToString(square)+", pieces="+piecesToString(pieces)+")");
    for(var i in pieces)
    {
      var piece = pieces[i];
      if(piece.col == square[0] && piece.row == square[1]) {
        //console.log("finished findGridElement(square="+coordinatesToString(square)+", pieces="+piecesToString(pieces)+") (found "+pieceToString(piece)+")");
        return piece;
      } 
    }
    //console.log("finished findGridElement(square="+coordinatesToString(square)+", pieces="+piecesToString(pieces)+") (no piece found)");
    return null;
  },

  isMovable: function(piece)
  {
    return (piece && that.params.constants.unmovablePieces.indexOf(piece.type) == -1)
  },

  //moves a piece from the board or the box to a square on the board
  //@piece: if on board has attributes "type", "col", "row" and "rotation"; if in box: has attributes "type" and "index"
  //@pieces: pieces on board
  //@boxedPieces: pieces outside of the board, in the so-called box
  //which is determined by examining the attributes of "piece"
  movePieceTo: function(piece, newSquare, pieces, boxedPieces)
  {
    if(isMovable(piece)) {
      //console.log("movePieceTo(piece="+pieceToString(piece)+", newSquare="+coordinatesToString(newSquare)+", pieces="+piecesToString(pieces)+", boxedPieces="+piecesToString(boxedPieces)+") - piece is movable");
      if (isOnBoard(newSquare)) { //defensive code
        //console.log("movePieceTo: correct arguments");
        if ((piece.col !== undefined) && (piece.row !== undefined)) { //the piece was on the board, let's change its coordinates
          //console.log("movePieceTo: piece was on board");
          var movedPiece = findGridElement([piece.col, piece.row], pieces);
          movedPiece.col = newSquare[0];
          movedPiece.row = newSquare[1];
        } else { //the piece was in the box, let's put it on the board
          //remove the piece from the "boxedPieces"
          //console.log("movePieceTo: piece was in box");
          takePieceOutOfBox(piece.type, boxedPieces);

          //add it to the "pieces" with the appropriate coordinates
          var insertedPiece = {
            "col": newSquare[0],
            "row": newSquare[1],
            "type": piece.type,
            "rotation": 0
          };
          pieces.push(insertedPiece);
        }
      } else {
        //console.log("movePieceTo: put outside of board, put piece in box");
        putPieceIntoBox(piece, pieces, boxedPieces);
      }
      //console.log("finished movePieceTo(piece="+pieceToString(piece)+", newSquare="+coordinatesToString(newSquare)+", pieces="+piecesToString(pieces)+", boxedPieces="+piecesToString(boxedPieces)+")");
    } else {
      //console.log("finished movePieceTo(piece="+pieceToString(piece)+", newSquare="+coordinatesToString(newSquare)+", pieces="+piecesToString(pieces)+", boxedPieces="+piecesToString(boxedPieces)+") - piece is not movable");
    }
  },

  //removes a piece form the boxed pieces and rearranges the remaining pieces
  takePieceOutOfBox: function(pieceType, boxedPieces)
  {
    //console.log("takePieceOutOfBox(pieceType="+pieceType+", boxedPieces="+piecesToString(boxedPieces)+")");
    for(var i in boxedPieces)
    {
      var piece = boxedPieces[i];
      if(piece.type == pieceType) {
        boxedPieces.splice(i, 1);
        //console.log("finished takePieceOutOfBox(pieceType="+pieceType+", boxedPieces="+piecesToString(boxedPieces)+")");
        return;
      }
    }
    //console.log("failed takePieceOutOfBox(pieceType="+pieceType+", boxedPieces="+piecesToString(boxedPieces)+")");
  },

  //@pieces: pieces on board
  //@boxedPieces: pieces outside of the board, in the so-called box
  putPieceIntoBox: function(piece, pieces, boxedPieces)
  {
    //console.log("putPieceIntoBox(piece="+pieceToString(piece)+", pieces="+piecesToString(pieces)+", boxedPieces="+piecesToString(boxedPieces)+")");
    if(piece.index == null) { //source of movement isn't the box
      var newIndex = boxedPieces.length;
      var boxedPiece = {
        "type": piece.type,
        "index": newIndex
      };
      //put at the right place
      //boxedPieces.splice(newIndex, 0, boxedPiece);
      boxedPieces.push(boxedPiece);

      for(var i in pieces)
      {
        var somePiece = pieces[i];
        if((piece.col == somePiece.col) &&(piece.row == somePiece.row)) {
          pieces.splice(i, 1);
          //console.log("finished putPieceIntoBox(piece="+pieceToString(piece)+", pieces="+piecesToString(pieces)+", boxedPieces="+piecesToString(boxedPieces)+")");
          return;
        }
      }
    } else { //the piece was moved from the box
      //console.log("finished putPieceIntoBox(piece="+pieceToString(piece)+", pieces="+piecesToString(pieces)+", boxedPieces="+piecesToString(boxedPieces)+") - did nothing");
    }
  },

  //selects a square if it is on the board
  selectSquare: function(square)
  {
    if(isOnBoard(square)) {
      selected.col = square[0];
      selected.row = square[1];
    }
  },

  //returns the coordinates of the square that was clicked on in the box, or null if outside of the box
  //@position: array of coordinates in pixels
  //@position: warning: needed attributes are not checked!
  getIndexInBox: function(position, constants)
  {
    //tests whether is in box or not
    var relativeX = position[0] - constants.boxLeft;
    var relativeY = position[1] - constants.boxTop;

    var col = Math.floor(relativeX/constants.boxCellSize[0]);
    var row = Math.floor(relativeY/constants.boxCellSize[1]);

    if((0 <= col) && (1 >= col) && (0 <= row) && (4 >= row)) {
      var index = 2*row+col;

      //console.log("getIndexInBox returns "+index);
      return index;
    }
    //console.log("getIndexInBox: out of box");
    return null;
  },

  //2D coordinates
  coordinatesToString: function(coordinates) {
    return "["+coordinates[0]+", "+coordinates[1]+"]";
  },

  //2D coordinates
  xyCoordinatesToString: function(coordinates) {
    return "["+coordinates.x+", "+coordinates.y+"]";
  },

  pieceToString: function(piece) {
    if(piece) return "{col:"+piece.col+", row:"+piece.row+", type:"+piece.type+"}";
    else return piece;
  },

  piecesToString: function(pieces) {
    var printed = "{";
    for(var i in pieces)
    {
      var piece = pieces[i];
      if(printed !== "{") {
        printed+=", ";
      }
      printed+=pieceToString(piece);
    }
    printed += "}";
    return printed;
  },

  paramsToString: function(params) {
    if (params)
      return "params={selectedPiece="+pieceToString(params.selectedPiece)+", draggedPiece="+pieceToString(params.draggedPiece)+")";
    else
      return params;
  },

  //updates selected piece and dragged piece when the mouse button is pressed on a piece
  mouseDownOnPiece: function(piecePressed, params) {
    //console.log("mouseDownOnPiece(piecePressed="+pieceToString(piecePressed)+", "+paramsToString(params)+")");
    if(piecePressed) {
      //console.log("action.js: clicked on piece of type \""+piecePressed.type+"\"");
      //console.log("action.js: the previously selected piece is unselected");
      params.selectedPiece = null;
      //console.log("rotating = false");
      params.rotating = false;
      params.originalRotation = null;
      params.originalPieceRotation = null;

      //console.log("action.js: \""+piecePressed.type+"\" starts to be dragged, even if a piece was already being dragged");
      if(isMovable(piecePressed)) {
        params.draggedPiece = piecePressed;
      }
      //console.log("finished mouseDownOnPiece(piecePressed="+pieceToString(piecePressed)+", "+paramsToString(params)+")");
    } else {
      //console.log("finished mouseDownOnPiece(piecePressed="+pieceToString(piecePressed)+", "+paramsToString(params)+"), nothing done");
    }
  },

  //tests whether a given position is inside the board or not
  //@positionOnBoard: array of coordinates as column and row position
  isOnBoard: function(positionOnBoard) {
    return ((positionOnBoard[0] <= 13) && (positionOnBoard[0] >= 0) && (positionOnBoard[1] <= 8) && (positionOnBoard[1] >= 0));
  },

  distance: function(point1, point2) {
    var point1x = point1[0] || point1.x;
    var point1y = point1[1] || point1.y;
    var point2x = point2[0] || point2.x;
    var point2y = point2[1] || point2.y;
    var diffX = point1x - point2x;
    var diffY = point1y - point2y;
    return Math.sqrt(diffX*diffX + diffY*diffY);        
  },

  areSamePiece: function(piece1, piece2) {
    return (piece1 && piece2 && (piece1.col == piece2.col) && (piece1.row == piece2.row))
  },

  drawObject: function(layer, assetName, assetSize, scale, col, row, constants, rotation) {
    GE.addUnique(that.params.graphics.shapes, {
      type: "image",
      layer: layer,
      asset: assetName,
      scale: scale,
      position: [-assetSize/2, -assetSize/2],
      translation: [(col+0.5) * constants.cellSize + constants.upperLeftBoardMargin, 
                    (row+0.5) * constants.cellSize + constants.upperLeftBoardMargin],
      rotation: rotation // In degrees 
    });
  },

  isInGrid: function(point)
  {
    return point[0] >= 0 && point[0] < gridSize[0] && point[1] >= 0 && point[1] < gridSize[1];        
  },

  // Attempts to find intersection with the given lines and returns it.
  // Else returns null.
  findIntersection: function(origin, dest, lines)
  {
    var closestIntersection = null;
    var distanceToClosestIntersection = Infinity;
    for(var i = 0; i < lines.length; i++)
    {
      // extend lines slightly
      var a = Vector.create(lines[i][0]);
      var b = Vector.create(lines[i][1]);
      var aToB = b.subtract(a);
      var midpoint = a.add(aToB.multiply(0.5));
      var newLength = (1 + EXTEND_LINES_FACTOR) * aToB.modulus();
      var unit = aToB.toUnitVector();
      var aExtend = midpoint.add(unit.multiply(-0.5 * newLength));
      var bExtend = midpoint.add(unit.multiply(0.5 * newLength));

      var intersection = Line.Segment.create(origin, dest).intersectionWith(Line.Segment.create(aExtend, bExtend));
      if(intersection) 
      {
        // the intersection will be in 3D, so we need to cast the origin to 3D as well or distance calculation will fail (returns null)
        var distanceToIntersection = Vector.create(origin).to3D().distanceFrom(intersection);
        if(distanceToIntersection < distanceToClosestIntersection) 
        {
          closestIntersection = intersection;
          distanceToClosestIntersection = distanceToIntersection;
        }
      }
    }

    return closestIntersection == null ? null : closestIntersection.elements.slice(0, 2); // return only 2D part
  },

  // Returns an intersection point with walls, or null otherwise
  intersectsBoundaries: function(origin, dest)
  {
    var boundaries = 
    [
      [[0, 0], [gridSize[0], 0]], // top
      [[gridSize[0], 0], [gridSize[0], gridSize[1]]], // right
      [[gridSize[0], gridSize[1]], [0, gridSize[1]]], // bottom
      [[0, gridSize[1]], [0, 0]] // left
    ];

    return findIntersection(origin, dest, boundaries);
  },

  // Returns an intersection point with walls, or null otherwise
  intersectsCell: function(origin, dest, cellPos)
  {
    var boundaries = 
    [
      [[cellPos[0], cellPos[1]], [cellPos[0], cellPos[1] + 1]], // top
      [[cellPos[0], cellPos[1] + 1], [cellPos[0] + 1, cellPos[1] + 1]], // right
      [[cellPos[0] + 1, cellPos[1] + 1], [cellPos[0] + 1, cellPos[1]]], // bottom
      [[cellPos[0] + 1, cellPos[1]], [cellPos[0], cellPos[1]]] // left
    ];

    return findIntersection(origin, dest, boundaries);
  },

  findGridElement: function(point)
  {
    for(var i in that.params.pieces)
    {
      var piece = that.params.pieces[i];
      if(piece.col == Math.floor(point[0]) && piece.row == Math.floor(point[1])) return piece; 
    }
    return null;
  },

  handleGridElement: function()
  {
    if(element.type == "wall")
    {
      // find intersection with wall
      var wallIntersection = intersectsCell(lightSegments[lightSegments.length - 1].origin, lightDestination, [element.col, element.row]);
      if(wallIntersection == null) throw new Error("Cannot find intersection with wall");
      lightSegments[lightSegments.length - 1].destination = wallIntersection;

      lightIntensity = 0;
    }
    else if(element.type == "mirror")
    {
      // find intersection with central line
      var rotation = element.rotation * Math.PI / 180; 
      var centralLineDiff = [.5 * Math.cos(rotation), .5 * Math.sin(rotation)];
      var centralLine = [[element.col + 0.5 + centralLineDiff[0], element.row + 0.5 + centralLineDiff[1]], [element.col + 0.5 - centralLineDiff[0], element.row + 0.5 - centralLineDiff[1]]];
      if(intersection = findIntersection(lightSegments[lightSegments.length - 1].origin, lightDestination, [centralLine]))
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
  },

  lightDirectionUpdated: function()
  {
    lightSigns = [lightDirection[0] > 0 ? 1 : -1, lightDirection[1] > 0 ? 1 : -1];

    var distanceOutOfGrid = Math.sqrt(gridSize[0]*gridSize[0] + gridSize[1]*gridSize[1]);
    var lastOrigin = lightSegments[lightSegments.length - 1].origin;
    lightDestination = Sylvester.Vector.create(lastOrigin).add(Sylvester.Vector.create(lightDirection).multiply(distanceOutOfGrid)).elements.slice();
  },

  // all lines are in grid space, not in screen space
  // options override default values for all drawn shapes (layer, composition, etc.)
  drawGradientLine: function(origin, dest, innerRadius, outerRadius, colorRgba, options)
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
  },

  findGridElement: function(point)
  {
    for(var i in that.params.pieces)
    {
      var piece = that.params.pieces[i];
      if(piece.col == Math.floor(point[0]) && piece.row == Math.floor(point[1])) return piece; 
    }
    return null;
  },

  isRotatable: function(piece)
  {
    return (piece && that.params.constants.unrotatablePieces.indexOf(piece.type) == -1)
  },

  //converts a pixel coordinate to a board coordinate
  //assumes that the board is made out of squares
  toBoardCoordinate: function(pixelCoordinate)
  {
    var res = Math.floor((pixelCoordinate - that.params.constants.upperLeftBoardMargin)/that.params.constants.cellSize);
    return res;
  },

  findGridElement: function(point)
  {
    for(var i in that.params.pieces)
    {
      var piece = that.params.pieces[i];
      if(piece.col == Math.floor(point[0]) && piece.row == Math.floor(point[1])) return piece; 
    }
    return null;
  },

  //returns the coordinates of the square that was clicked on in the box, or null if outside of the box
  //@position: array of coordinates in pixels
  //@position: warning: needed attributes are not checked!
  getIndexInBox: function(position, constants) {
    //tests whether is in box or not
    var relativeX = position[0] - constants.boxLeft;
    var relativeY = position[1] - constants.boxTop;

    var col = Math.floor(relativeX/constants.boxCellSize[0]);
    var row = Math.floor(relativeY/constants.boxCellSize[1]);

    if((0 <= col) && (1 >= col) && (0 <= row) && (4 >= row)) {
      var index = 2*row+col;
      return index;
    }
    return null;
  },

  getBoxedPiece: function(index) {
    return index == null ? null : that.params.boxedPieces[index];
  }
})