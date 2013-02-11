# Get alias for the global scope
globals = @

describe "gamEvolve", ->
  beforeEach ->
    @addMatchers 
      toDeeplyEqual: (expected) -> _.isEqual(@actual, expected)
      toBeEmpty: (expected) -> expected.length == 0

  describe "model", ->
    it "can be created empty", ->
      model = new GE.Model()
      expect(model.version).toEqual(0)
      expect(model.data).toDeeplyEqual({})

    it "can be created with data", ->
      model = new GE.Model({a: 1, b: 2})
      expect(model.version).toEqual(0)
      expect(model.data).toDeeplyEqual({a: 1, b: 2})

    it "can be patched", ->
      # Create old data, new data, and the patches between
      oldData = 
        a: 1
        b: 
          b1: true
          b2: "hi"
      newData = 
        b: 
          b1: true
          b2: "there"
        c: 
          bob: "is cool"
      patches = GE.makePatches(oldData, newData)

      # Create model objects of the data
      oldModel = new GE.Model(oldData)
      newModel = oldModel.applyPatches(patches)

      # The new model and the old model should still both be valid and different
      expect(oldModel.version).toEqual(0)
      expect(oldModel.data).toDeeplyEqual(oldData)
      expect(newModel.version).toEqual(1)
      expect(newModel.data).toDeeplyEqual(newData)

    it "rejects conflicting patches", ->
      # Create old data, new data, and the patches between
      oldData = 
        a: 1
      newDataA = 
        a: 2 
      newDataB = 
        b: 3
      patchesA = GE.makePatches(oldData, newDataA)
      patchesB = GE.makePatches(oldData, newDataB)

      # Create model objects of the data
      oldModel = new GE.Model(oldData)
      expect(-> oldModel.applyPatches(_.flatten([patchesA, patchesB]))).toThrow()

  describe "runSteps", ->
    it "calls functions", ->
      # make test function to spy on
      globals.testFunction = jasmine.createSpy()

      layout = 
        call: "testFunction"
        params: [1, 2]

      GE.runStep(new GE.Model(), null, null, layout)

      expect(globals.testFunction).toHaveBeenCalledWith(1, 2)

    it "calls actions", ->
      isCalled = false

      actions = 
        doNothing: 
          paramDefs:
            x: 1
            y: "z"
          update: ->
            isCalled = true
            expect(arguments.length).toEqual(0)
            expect(@params).toDeeplyEqual
              x: 2
              y: "z"

      layout = 
        action: "doNothing"
        params: 
          x: 2
          y: "z"

      GE.runStep(new GE.Model(), null, actions, layout)
      expect(isCalled).toBeTruthy()

    it "calls children of actions", ->
      timesCalled = 0

      actions = 
        doNothing: 
          paramDefs: {}
          update: -> timesCalled++

      layout = 
        action: "doNothing"
        params: {}
        children: [
          {
            action: "doNothing"
            params: {}
          },
          {
            action: "doNothing"
            params: {}
          }
        ]

      GE.runStep(new GE.Model(), null, actions, layout)
      expect(timesCalled).toEqual(3)

    it "evaluates parameters for functions", ->
      model = new GE.Model({ person: { firstName: "bob" } })

      assets = { image: new Image() }

      # make test function to spy on
      globals.testFunction = jasmine.createSpy()

      layout = 
        bind: 
          select: 
            lastName: "jon"
        children: [
          { 
            call: "testFunction"
            params: ["@model:person.firstName", "model", "$lastName", "@asset:image"]
          }
        ]
      GE.runStep(model, assets, null, layout)

      expect(globals.testFunction).toHaveBeenCalledWith("bob", "model", "jon", assets.image)

    it "evaluates parameters for actions", ->
      oldModel = new GE.Model
        a: 1
        b: 10
        c: 20

      assets = { image: new Image() }

      actions = 
        adjustModel: 
          paramDefs:
            x: null
            y: null
            z: null
            d: 2
            e: null
          update: ->
            @params.x++
            @params.y--
            @params.z = 30
            expect(@params.d).toBe(2)
            expect(@params.e).toBe(assets.image)

      layout = 
        bind: 
          select:
            c: "@model:b"
            z: "@model:c"
            e: "@asset:image"
        children: [
          action: "adjustModel"
          params: 
            x: "@model:a"
            y: "$c"
        ]

      [result, patches] = GE.runStep(oldModel, assets, actions, layout)
      newModel = oldModel.applyPatches(patches)

      # The new model should be changed, but the old one shouldn't be
      expect(oldModel.data.a).toBe(1)
      expect(oldModel.data.b).toBe(10)
      expect(oldModel.data.c).toBe(20)
      expect(newModel.data.a).toBe(2)
      expect(newModel.data.b).toBe(9)
      expect(newModel.data.c).toBe(30)

    it "sets the model", ->
      oldModel = new GE.Model
        a: 
          a1: 1
        b: 10
        c: "hi"

      layout = 
        setModel: 
          "a.a1": 2
          "b": "@model:c"

      [result, patches] = GE.runStep(oldModel, null, null, layout)
      newModel = oldModel.applyPatches(patches)

      # The new model should be changed, but the old one shouldn't be
      expect(oldModel.data.a.a1).toBe(1)
      expect(oldModel.data.b).toBe(10)
      expect(newModel.data.a.a1).toBe(2)
      expect(newModel.data.b).toBe("hi")

    it "checks and adjusts activation", ->
      models = [new GE.Model
        activeChild: 0
        child0TimesCalled: 0
        child1TimesCalled: 0
      ]

      actions = 
        nextOnDone: 
          paramDefs: 
            activeChild: 0
          listActiveChildren: -> return [@params.activeChild]
          handleSignals: ->
            if @signals[@params.activeChild] == GE.signals.DONE 
              @params.activeChild++
            if @params.activeChild >= @children.length - 1
              return GE.signals.DONE
        reportDone:
          paramDefs: 
            timesCalled: 0
          update: -> 
            @params.timesCalled++
            return GE.signals.DONE

      layout = 
        action: "nextOnDone"
        params: 
          activeChild: "@model:activeChild"
        children: [
          {
            action: "reportDone"
            params: 
              timesCalled: "@model:child0TimesCalled"
          },
          {
            action: "reportDone"
            params: 
              timesCalled: "@model:child1TimesCalled"
          }
        ]

      [result, patches] = GE.runStep(models[0], null, actions, layout)
      models[1] = models[0].applyPatches(patches)

      expect(models[1].data.child0TimesCalled).toBe(1)
      expect(models[1].data.child1TimesCalled).toBe(0)
      expect(models[1].data.activeChild).toBe(1)
      
      [result, patches] = GE.runStep(models[1], null, actions, layout)
      models[2] = models[1].applyPatches(patches)

      expect(models[2].data.child0TimesCalled).toBe(1)
      expect(models[2].data.child1TimesCalled).toBe(1)
      expect(models[2].data.activeChild).toBe(2)

    it "binds across model arrays", ->
      oldModel = new GE.Model
        people: [
          { first: "bill", last: "bobson" }
          { first: "joe", last: "johnson" }
        ]

      actions = 
        changeName: 
          paramDefs:
            newName: "" 
            toChange: ""
          update: -> @params.toChange = @params.newName

      layout = 
        bind: 
          from:
            person: "@model:people"
        children: [
          { 
            action: "changeName"
            params: 
              newName: "$person.first"
              toChange: "$person.last"
          }
        ]

      [result, patches] = GE.runStep(oldModel, null, actions, layout)
      newModel = oldModel.applyPatches(patches)

      expect(newModel.data.people[0].last).toBe("bill")
      expect(newModel.data.people[1].last).toBe("joe")

    it "binds across constant arrays", ->
      oldModel = new GE.Model()
      people = [
        { first: "bill", last: "bobson" }
        { first: "joe", last: "johnson" }
      ]

      # make test function to spy on
      globals.testFunction = jasmine.createSpy()

      layout = 
        bind: 
          from:
            person: people
        children: [
          { 
            call: "testFunction"
            params: ["$person"]
          }
        ]

      GE.runStep(oldModel, null, null, layout)

      for person in people
        expect(globals.testFunction).toHaveBeenCalledWith(person)
    
