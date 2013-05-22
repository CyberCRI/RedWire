# Get alias for the global scope
globals = @

describe "gamEvolve", ->
  beforeEach ->
    @addMatchers 
      toDeeplyEqual: (expected) -> _.isEqual(@actual, expected)
      toBeEmpty: () -> @actual.length == 0

  describe "patches", ->
    it "can remove value from array", ->
      a = 
        v: [10..15]
      b = 
        v: [10, 12, 13, 14, 15] # Missing 11

      patches = GE.makePatches(a, b)
      patchResult = GE.applyPatches(patches, a)

      expect(patchResult).toDeeplyEqual(b)

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

    it "can be retrieved at a given version", ->
      v0 = 
        a: 0
      v1 =
        a: 1
      v2 = 
        a: 2

      model = new GE.Model(v0).setData(v1).setData(v2)

      expect(model.clonedData()).toDeeplyEqual(v2)
      expect(model.version).toBe(2)

      expect(model.atVersion(1).clonedData()).toDeeplyEqual(v1)
      expect(model.atVersion(1).version).toBe(1)

      expect(model.atVersion(0).clonedData()).toDeeplyEqual(v0)
      expect(model.atVersion(0).version).toBe(0)


  describe "visitNode()", ->
    it "calls functions", ->
      # make test function to spy on
      globals.testFunction = jasmine.createSpy()

      layout = 
        call: "testFunction"
        params: [1, 2]

      constants = new GE.NodeVisitorConstants({}, {}, {}, {})
      GE.visitNode(layout, constants, {})

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

      constants = new GE.NodeVisitorConstants({}, {}, {}, actions)
      GE.visitNode(layout, constants, {})
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

      constants = new GE.NodeVisitorConstants({}, {}, {}, actions)
      GE.visitNode(layout, constants, {})
      expect(timesCalled).toEqual(3)

    it "evaluates parameters for functions", ->
      model = { person: { firstName: "bob" } }

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

      constants = new GE.NodeVisitorConstants(model, {}, assets, {})
      GE.visitNode(layout, constants, {})

      expect(globals.testFunction).toHaveBeenCalledWith("bob", "model", "jon", assets.image)

    it "evaluates parameters for actions", ->
      oldModel = 
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

      constants = new GE.NodeVisitorConstants(oldModel, {}, assets, actions)
      results = GE.visitNode(layout, constants, {})
      newModel = GE.applyPatches(results.modelPatches, oldModel)

      # The new model should be changed, but the old one shouldn't be
      expect(oldModel.a).toBe(1)
      expect(oldModel.b).toBe(10)
      expect(oldModel.c).toBe(20)
      expect(newModel.a).toBe(2)
      expect(newModel.b).toBe(9)
      expect(newModel.c).toBe(30)

    it "sets the model", ->
      oldModel = 
        a: 
          a1: 1
        b: 10
        c: "hi"

      layout = 
        setModel: 
          "a.a1": 2
          "b": "@model:c"

      constants = new GE.NodeVisitorConstants(oldModel, {}, {}, {})
      results = GE.visitNode(layout, constants, {})
      newModel = GE.applyPatches(results.modelPatches, oldModel)

      # The new model should be changed, but the old one shouldn't be
      expect(oldModel.a.a1).toBe(1)
      expect(oldModel.b).toBe(10)
      expect(newModel.a.a1).toBe(2)
      expect(newModel.b).toBe("hi")

    it "checks and adjusts activation", ->
      models = [
        {
          activeChild: 0
          child0TimesCalled: 0
          child1TimesCalled: 0
        }
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

      constants = new GE.NodeVisitorConstants(models[0], {}, {}, actions)
      results = GE.visitNode(layout, constants, {})
      models[1] = GE.applyPatches(results.modelPatches, models[0])

      expect(models[1].child0TimesCalled).toBe(1)
      expect(models[1].child1TimesCalled).toBe(0)
      expect(models[1].activeChild).toBe(1)
      
      constants = new GE.NodeVisitorConstants(models[1], {}, {}, actions)
      results = GE.visitNode(layout, constants, {})
      models[2] = GE.applyPatches(results.modelPatches, models[1])

      expect(models[2].child0TimesCalled).toBe(1)
      expect(models[2].child1TimesCalled).toBe(1)
      expect(models[2].activeChild).toBe(2)

    it "binds across model arrays", ->
      oldModel = 
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

      constants = new GE.NodeVisitorConstants(oldModel, {}, {}, actions)
      results = GE.visitNode(layout, constants, {})
      newModel = GE.applyPatches(results.modelPatches, oldModel)

      expect(newModel.people[0].last).toBe("bill")
      expect(newModel.people[1].last).toBe("joe")

    it "communicates with services", ->
      oldServiceData = 
        serviceA: 
          a: 1

      actions = 
        incrementServiceData: 
          paramDefs:
            service: "" 
          update: -> 
            expect(@params.service.a).toBe(1)
            @params.service.a++

      layout = 
        action: "incrementServiceData"
        params:
          service: "@service:serviceA"

      constants = new GE.NodeVisitorConstants({}, oldServiceData, {}, actions)
      results = GE.visitNode(layout, constants, {})
      newServiceData = GE.applyPatches(results.servicePatches, oldServiceData)

      expect(newServiceData.serviceA.a).toBe(2)

  describe "stepLoop()", ->
    it "sends output data directly to services", ->
      services = 
        myService:
          establishData: jasmine.createSpy()

      outputServiceData = 
        myService:
          a = 1

      # parameters: node, modelData, assets, actions, services, log, inputServiceData = null, outputServiceData = null
      modelPatches = GE.stepLoop(null, {}, {}, {}, {}, services, null, null, outputServiceData)

      expect(services.myService.establishData).toHaveBeenCalledWith(outputServiceData.myService, {})
      expect(modelPatches).toBeEmpty()

    it "send service input data to visitNode", ->
      services = 
        myService:
          establishData: jasmine.createSpy()

      inputServiceData = 
        myService:
          a: 1

      actions = 
        incrementServiceData: 
          paramDefs:
            service: "" 
          update: -> 
            expect(@params.service.a).toBe(1)
            @params.service.a++

      layout = 
        action: "incrementServiceData"
        params:
          service: "@service:myService"

      # parameters: node, modelData, assets, actions, services, log, inputServiceData = null, outputServiceData = null
      modelPatches = GE.stepLoop(layout, {}, {}, actions, {}, services, null, inputServiceData)

      expect(services.myService.establishData).toHaveBeenCalledWith({ a: 2 }, {})
      expect(modelPatches).toBeEmpty()

    it "gathers service input data, visits nodes, and gives output to services", ->
      services = 
        myService:
          provideData: -> return { a: 1 }
          establishData: jasmine.createSpy()

      spyOn(services.myService, "provideData").andCallThrough()

      actions = 
        incrementServiceData: 
          paramDefs:
            service: "" 
          update: -> 
            expect(@params.service.a).toBe(1)
            @params.service.a++

      layout = 
        action: "incrementServiceData"
        params:
          service: "@service:myService"

      # parameters: node, modelData, assets, actions, services, log, inputServiceData = null, outputServiceData = null
      modelPatches = GE.stepLoop(layout, {}, {}, actions, {}, services)

      expect(services.myService.provideData).toHaveBeenCalledWith({})
      expect(services.myService.establishData).toHaveBeenCalledWith({ a: 2 }, {})
      expect(modelPatches).toBeEmpty()

    it "rejects conflicting patches", ->
      # Create old data, new data, and the patches between
      oldData = 
        a: 0

      services = 
        myService:
          provideData: -> return { a: 0 }
          establishData: jasmine.createSpy()

      actions = 
        group:
          paramDefs: {}
          update: ->
        setDataTo: 
          paramDefs:
            var: null
            value: null
          update: -> @params.var = @params.value

      layoutA = 
        action: "group"
        children: [
          {
            action: "setDataTo"
            params:
              var: "@model:a"
              value: 1
          },
          {
            action: "setDataTo"
            params:
              var: "@model:a"
              value: 2
          }
        ]

      # parameters: node, modelData, assets, actions, services, log, inputServiceData = null, outputServiceData = null
      expect(-> GE.stepLoop(layoutA, oldData, {}, actions, {}, {})).toThrow()
      
      layoutB = 
        action: "group"
        children: [
          {
            action: "setDataTo"
            params:
              var: "@service:myService.a"
              value: 1
          },
          {
            action: "setDataTo"
            params:
              var: "@service:myService.a"
              value: 2
          }
        ]

      # parameters: node, modelData, assets, actions, services, log, inputServiceData = null, outputServiceData = null
      expect(-> GE.stepLoop(layoutB, {}, {}, actions, {}, services)).toThrow()
      
