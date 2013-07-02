({
  // Add a shape to be drawn to graphics
  drawShape: function(shape, oldShapes) 
  {
    var shapes = oldShapes || {};
    shapes[_.uniqueId()] = shape;
    return shapes; 
  },

  // Checks if a point intersects a shape.
  // Currently does not take rotation into account, and only supports circles and rectangles.
  // Requires Sylvester.js
  pointIntersectsShape: function(point, shape)
  {
    switch(shape.type)
    {
      case "circle":
        var center = Vector.create(shape.center);
        if(shape.translation) center = center.add(shape.translation);
        return center.distanceFrom(Vector.create(point)) < shape.radius * (shape.scale || 1);

      case "rectangle":
        // Move the point to the frame of the shape
        var pointInShapeFrame = Vector.create(point);
        if(shape.translation) pointInShapeFrame = pointInShapeFrame.subtract(shape.translation);
        return pointInShapeFrame.elements[0] >= shape.position[0] && pointInShapeFrame.elements[0] <= shape.position[0] + shape.size[0] &&
          pointInShapeFrame.elements[1] >= shape.position[1] && pointInShapeFrame.elements[1] <= shape.position[1] + shape.size[1];

      default:
        throw new Error("Shape type '" + shape.type + "' is not supported");
    }
  },

  //returns a copy of 'tab' without the element at position 'index'
  pureRemove: function(index, tab)
  {
    var res = tab.slice(0, index).concat(tab.slice(index+1, tab.length+1));
    return res;
  },

  //returns a copy of 'pieces' with the piece 'oldPiece' replaced by 'newPiece' if 'oldPiece' was present in 'pieces'
  replace: function(oldPiece, newPiece, pieces)
  {
    for(var i in pieces)
    {
      var piece = pieces[i];
      if(piece.col === oldPiece.col && piece.row === oldPiece.row) {
        result = pieces.slice(0, i).concat(newPiece).concat(pieces.slice(i+1, pieces.length));
        return result;
      } 
    }
    return pieces;
  },

  copyPiece: function(p)
  {
    if(p.col !== undefined) return this.copyBoardPiece(p);
    else return this.copyBoxedPiece(p);
  },

  //returns a copy of a board piece
  copyBoardPiece: function(p)
  {
     return {col: p.col, row: p.row, type: p.type, rotation: p.rotation};
  },

  //returns a copy of a board piece
  copyBoxedPiece: function(p)
  {
     return {type: p.type };
  },

  copyBoardPieces: function(ps)
  {
    var res = new Array();
    for (var i in ps)
    {
      res[i] = this.copyBoardPiece(ps[i]);
    }
    return res;
  },

  //copies an obj
  //warning: unsafe if obj contains links to other objects
  copyBoxedPieces: function(ps)
  {
    var res = new Array();
    for (var i in ps)
    {
      res[i] = this.copyBoxedPiece(ps[i]);
    }
    return res;
  },

  //copies an obj
  //warning: unsafe if obj contains links to other objects
  copy: function(obj)
  {
    var res = {};
    for (var field in obj)
    {
      res[field.toString] = obj[field.toString];
    }
    return res;
  },

  //converts a pixel coordinate to a board coordinate
  //assumes that the board is made out of squares
  toBoardCoordinate: function(pixelCoordinate, upperLeftBoardMargin, cellSize)
  {
    var res = Math.floor((pixelCoordinate - upperLeftBoardMargin)/cellSize);
    return res;
  },

  //does the opposite of toBoardCoordinate
  toPixelCoordinate: function(boardCoordinate, upperLeftBoardMargin, cellSize)
  {
    return (boardCoordinate + 0.5)*(cellSize-1) + upperLeftBoardMargin;
  },

  //returns the piece at position 'square' on the board, or null if there is none
  findGridElement: function(square, pieces)
  {
    if(square === null) return null;

    for(var i in pieces)
    {
      var piece = pieces[i];
      if(piece.col == square[0] && piece.row == square[1]) {
        return piece;
      } 
    }
    return null;
  },

  isMovable: function(piece, unmovablePieces)
  {
    return (piece && unmovablePieces.indexOf(piece.type) == -1);
  },

  //moves a piece from the board or the box to a square on the board
  //@piece: if on board has attributes "type", "col", "row" and "rotation"; if in box: has attributes "type" and "index"
  //@pieces: pieces on board
  //@boxedPieces: pieces outside of the board, in the so-called box
  //which is determined by examining the attributes of "piece"
  //
  //returns {piece, pieces, boxedPiece}
  //piece is the updated piece
  //pieces is the update table of board pieces
  //boxedPieces is the update table of boxed pieces
  movePieceTo: function(piece, newSquare, pieces, boxedPieces, gridSize, unmovablePieces)
  {
    var newPiece = this.copyPiece(piece);
    var newPieces = this.copyBoardPieces(pieces);
    var newBoxedPieces = this.copyBoxedPieces(boxedPieces);

    if(this.isMovable(piece, unmovablePieces)) {
      if (this.isInGrid(newSquare, gridSize)) { //defensive code
        if ((piece.col !== undefined) && (piece.row !== undefined)) { //the piece was on the board, let's change its coordinates
          //console.log("movePieceTo the piece was on the board, let's change its coordinates");
          //var movedPiece = findGridElement([piece.col, piece.row], pieces);
          //movedPiece.col = newSquare[0];
          //movedPiece.row = newSquare[1];
          newPiece.col = newSquare[0];
          newPiece.row = newSquare[1];
          newPieces    = this.replace(piece, newPiece, pieces);

        } else { //the piece was in the box, let's put it on the board
          //console.log("movePieceTo the piece was in the box, let's put it on the board");
          //remove the piece from the "boxedPieces"
          newBoxedPieces = this.takePieceOutOfBox(piece.type, boxedPieces);

          //add it to the "pieces" with the appropriate coordinates
          newPiece = {
            "col": newSquare[0],
            "row": newSquare[1],
            "type": piece.type,
            "rotation": 0
          };
          newPieces = pieces.concat([newPiece]);
        }
      } else {
        //the new square position is outside of the board: let's box the piece
        //console.log("movePieceTo the new square position is outside of the board: let's box the piece");
        var put = this.putPieceIntoBox(piece, pieces, boxedPieces);
        newPiece = put.piece;
        newPieces = put.pieces;
        newBoxedPieces = put.boxedPieces;
      }
      //console.log("finished movePieceTo(piece="+this.pieceToString(piece)+", newSquare="+this.coordinatesToString(newSquare)+", pieces="+this.piecesToString(pieces)+", boxedPieces="+this.piecesToString(boxedPieces)+")");
    } else {
      //console.log("finished movePieceTo(piece="+this.pieceToString(piece)+", newSquare="+this.coordinatesToString(newSquare)+", pieces="+this.piecesToString(pieces)+", boxedPieces="+this.piecesToString(boxedPieces)+") - piece is not movable");
    }

    var toReturn = {};
    toReturn.piece                  = newPiece;
    toReturn.pieces                 = newPieces;
    toReturn.boxedPieces            = newBoxedPieces;

    toReturn.selectedPiece          = null; //draggedPiece ?
    toReturn.draggedPiece           = null;
    toReturn.rotating               = false;
    toReturn.originalRotation       = null;
    toReturn.originalPieceRotation  = null;

    return toReturn;
  },

  //returns boxedPieces minus a piece of type "pieceType"
  //besides, boxedPieces is still sorted afterwards
  takePieceOutOfBox: function(pieceType, boxedPieces)
  {
    //console.log("takePieceOutOfBox(pieceType="+pieceType+", boxedPieces="+this.piecesToString(boxedPieces)+")");
    for(var i in boxedPieces)
    {
      var piece = boxedPieces[i];
      if(piece.type === pieceType) {
        var res = this.pureRemove(i, boxedPieces);
        //console.log("finished takePieceOutOfBox(pieceType="+pieceType+", boxedPieces="+this.piecesToString(boxedPieces)+")");
        //console.log("takePieceOutOfBox("+pieceType+", "+this.piecesToString(boxedPieces)+")="+this.piecesToString(res));
        return res;
      }
    }
    //console.log("failed takePieceOutOfBox(pieceType="+pieceType+", boxedPieces="+this.piecesToString(boxedPieces)+")");
  },

  //takes a piece 'piece' from the board, i.e. 'pieces', and puts it into the box, i.e. 'boxedPieces'
  //@piece: the piece to be moved
  //@pieces: pieces on board
  //@boxedPieces: pieces outside of the board, in the so-called box
  //returns {boxedPiece, pieces, boxedPieces}
  putPieceIntoBox: function(piece, pieces, boxedPieces)
  {
    //console.log("putPieceIntoBox(piece="+this.pieceToString(piece)+", pieces="+this.piecesToString(pieces)+", boxedPieces="+this.piecesToString(boxedPieces)+")");

    var res = {};

    if(piece.row !== undefined) { //source of movement isn't the box
      //console.log("putPieceIntoBox: source of movement isn't the box");
      res.boxedPiece = {
        "type": piece.type
      };
      //put at the right place
      //boxedPieces.splice(newIndex, 0, boxedPiece);
      res.boxedPieces = boxedPieces.concat(res.boxedPiece);

      for(var i in pieces)
      {
        var somePiece = pieces[i];
        if((piece.col == somePiece.col) &&(piece.row == somePiece.row)) {
          res.pieces = this.pureRemove(i, pieces);
          //console.log("finished putPieceIntoBox: res={newBoxedPiece="+this.pieceToString(res.boxedPiece)+", newPieces="+this.piecesToString(res.pieces)+", newBoxedPieces="+this.piecesToString(res.boxedPieces)+"}");
          return res;
        }
      }
    } else { //the piece was moved from the box
      //console.log("putPieceIntoBox: the piece was moved from the box");
      //console.log("finished putPieceIntoBox(piece="+this.pieceToString(piece)+", pieces="+this.piecesToString(pieces)+", boxedPieces="+this.piecesToString(boxedPieces)+") - did nothing");
    }

    //console.log("putPieceIntoBox: no change");

    res.boxedPiece = piece;
    res.pieces = pieces;
    res.boxedPieces = boxedPieces;

    return res;
  },

  //returns the coordinates of the square that was clicked on in the box, or null if outside of the box
  //@position: array of coordinates in pixels
  //@position: warning: needed attributes are not checked!
  getIndexInBox: function(position, boxLeft, boxTop, boxCellSize, boxRowsCount, boxColumnsCount)
  {
    //tests whether is in box or not
    var relativeX = position[0] - boxLeft;
    var relativeY = position[1] - boxTop;

    var col = Math.floor(relativeX/boxCellSize[0]);
    var row = Math.floor(relativeY/boxCellSize[1]);

    if((0 <= col) && (boxColumnsCount > col) && (0 <= row) && (boxRowsCount > row)) {
      var index = 2*row+col;

      //console.log("getIndexInBox returns "+index);
      return index;
    }
    //console.log("getIndexInBox: out of box");
    return null;
  },

  //2D coordinates
  coordinatesToString: function(coordinates) {
    var x = coordinates[0] || coordinates.x;
    var y = coordinates[1] || coordinates.y;
    return "["+x+", "+y+"]";
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
        printed += ", ";
      }
      printed += this.pieceToString(piece);
    }
    printed += "}";
    return printed;
  },

  //@params: must have attributes "selectedPiece" and "draggedPiece"
  paramsToString: function(params) {
    if (params)
      return "params={selectedPiece="+this.pieceToString(params.selectedPiece)+", draggedPiece="+this.pieceToString(params.draggedPiece)+")";
    else
      return params;
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

  //returns a drawable object that represents a device of type 'assetName' on the board, at position [col, row]
  getDrawableObject: function(layer, assetName, scale, assetSize, col, row, cellSize, upperLeftBoardMargin, rotation) {
    return {
      type: "image",
      layer: layer,
      asset: assetName,
      scale: scale,
      position: [-assetSize/2, -assetSize/2],
      translation: [(col+0.5) * cellSize + upperLeftBoardMargin, 
                    (row+0.5) * cellSize + upperLeftBoardMargin],
      rotation: rotation // In degrees 
    };
  },

  //tests whether a given position is inside the board or not
  //@positionOnBoard: array of coordinates as column and row position
  isInGrid: function(point, gridSize)
  {
    return (point[0] >= 0) && (point[0] < gridSize[0]) && (point[1] >= 0) && (point[1] < gridSize[1]);        
  },

  // Attempts to find intersection with the given lines and returns it.
  // Else returns null.
  findIntersection: function(origin, dest, lines, extendLinesFactor)
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
      var newLength = (1 + extendLinesFactor) * aToB.modulus();
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

    return closestIntersection === null ? null : closestIntersection.elements.slice(0, 2); // return only 2D part
  },

  // Returns an intersection point with walls, or null otherwise
  intersectsBoundaries: function(origin, dest, gridSize, extendLinesFactor)
  {
    var boundaries = 
    [
      [[0, 0], [gridSize[0], 0]], // top
      [[gridSize[0], 0], [gridSize[0], gridSize[1]]], // right
      [[gridSize[0], gridSize[1]], [0, gridSize[1]]], // bottom
      [[0, gridSize[1]], [0, 0]] // left
    ];

    return this.findIntersection(origin, dest, boundaries, extendLinesFactor);
  },

  // Returns an intersection point with walls, or null otherwise
  intersectsCell: function(origin, dest, cellPos, extendLinesFactor)
  {
    var boundaries = 
    [
      [[cellPos[0], cellPos[1]], [cellPos[0], cellPos[1] + 1]], // top
      [[cellPos[0], cellPos[1] + 1], [cellPos[0] + 1, cellPos[1] + 1]], // right
      [[cellPos[0] + 1, cellPos[1] + 1], [cellPos[0] + 1, cellPos[1]]], // bottom
      [[cellPos[0] + 1, cellPos[1]], [cellPos[0], cellPos[1]]] // left
    ];

    return this.findIntersection(origin, dest, boundaries, extendLinesFactor);
  },

  isRotatable: function(piece, unrotatablePieces)
  {
    return (piece && unrotatablePieces.indexOf(piece.type) == -1)
  },

  getBoxedPiece: function(index, boxedPieces) {
    return index === null ? null : boxedPieces[index];
  },

  // Not really generic, assumes that there are 2 cells per row and that they should be laid out row-first
  // TODO: why check the array length?
  gridCellToIndex: function(array, cell) {
    if(array === null || cell === null) return null;

    var index = 2 * cell[1] + cell[0];
    return index < array.length ? index : null;
  },

  // Not really generic, assumes that there are 2 cells per row and that they should be laid out row-first
  gridIndexToCell: function(index) {
    if(index === null) return null;

    return [index % 2, Math.floor(index / 2)];
  },

  gridCellAtPoint: function(grid, point) {
    if(point === null) return null;

    var gridPos = [
      Math.floor((point[0] - grid.upperLeft[0]) / grid.cellSize[0]),
      Math.floor((point[1] - grid.upperLeft[1]) / grid.cellSize[1])
    ];

    if(gridPos[0] < 0 || gridPos[0] > grid.gridSize[0] || gridPos[1] < 0 || gridPos[1] > grid.gridSize[1]) 
      return null;
    else
      return gridPos;
  },

  gridCellCenter: function(grid, cell, shape) {
    return [
      (cell[0] + 0.5) * grid.cellSize[0] + grid.upperLeft[0], 
      (cell[1] + 0.5) * grid.cellSize[1] + grid.upperLeft[1]
    ];
  }
})