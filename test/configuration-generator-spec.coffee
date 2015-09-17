_ = require 'lodash'
nodeUuid = require 'node-uuid'

ConfigurationGenerator = require '../src/configuration-generator'
sampleFlow = require './data/sample-flow.json'

describe 'ConfigurationGenerator', ->
  beforeEach ->
    @UUID = require 'node-uuid'
    sinon.stub @UUID, 'v1'

  afterEach ->
    @UUID.v1.restore()

  describe '-> configure', ->
    beforeEach ->
      @sut = new ConfigurationGenerator {server: 'some-server'}, {UUID: @UUID}

    describe 'when called', ->
      beforeEach (done) ->
        @UUID.v1.onCall(0).returns 'node-trigger-instance'
        @UUID.v1.onCall(1).returns 'node-debug-instance'
        @UUID.v1.onCall(2).returns 'node-interval-instance'
        @sut.configure sampleFlow, 'some-token', (@error, @flowConfig) => done()

      it 'should return a flow configuration with keys for all the nodes in the flow', ->
        expect(@flowConfig).to.contain.keys [
          '8a8da890-55d6-11e5-bd83-1349dc09f6d6'
          '8e74a6c0-55d6-11e5-bd83-1349dc09f6d6'
          '2cf457d0-57eb-11e5-99ea-11ac2aafbb8d'
        ]

      it 'should set the uuid and token of meshblu-output and merge meshbluJSON', ->
        expect(@flowConfig['engine-output'].config).to.deep.equal uuid: sampleFlow.flowId, token: 'some-token', server: 'some-server'

      it 'should return a flow configuration with virtual nodes', ->
        expect(@flowConfig).to.contain.keys [
          'engine-input'
          'engine-output'
          'router'
          'start'
          'stop'
        ]

      it 'should return a flow configuration with the router, io, nodes in the flow and the virtual nodes', ->
        expect(@flowConfig).to.contain.keys [
          '8a8da890-55d6-11e5-bd83-1349dc09f6d6'
          '8e74a6c0-55d6-11e5-bd83-1349dc09f6d6'
          '2cf457d0-57eb-11e5-99ea-11ac2aafbb8d'
          'engine-input'
          'engine-output'
          'router'
          'start'
          'stop'
        ]

      it 'should set the flow links on the router', ->
        links =
          '2cf457d0-57eb-11e5-99ea-11ac2aafbb8d':
            type: 'engine-input'
            linkedTo: ['node-interval-instance']
          '8a8da890-55d6-11e5-bd83-1349dc09f6d6':
            type: 'engine-input'
            linkedTo: ['node-trigger-instance']
          'node-trigger-instance':
            type: 'nanocyte-node-trigger'
            linkedTo: ['node-debug-instance']
          'node-debug-instance':
            type: 'nanocyte-node-debug'
            linkedTo: ['engine-debug']
          'node-interval-instance':
            type: 'nanocyte-node-interval'
            linkedTo: ['node-debug-instance']
          'engine-output':
            type: 'engine-output'
            linkedTo: []
          'engine-data':
            type: 'engine-data'
            linkedTo: []
          'engine-debug':
            type: 'engine-debug'
            linkedTo: []
          'engine-pulse':
            type: 'engine-pulse'
            linkedTo: []

        expect(@flowConfig.router.config).to.deep.equal links

      it 'should configure the debug node with the proper config', ->
        origNodeConfig = _.findWhere sampleFlow.nodes, id: '8e74a6c0-55d6-11e5-bd83-1349dc09f6d6'
        expect(@flowConfig['8e74a6c0-55d6-11e5-bd83-1349dc09f6d6'].config).to.deep.equal origNodeConfig

      it 'should configure the debug node with default data', ->
        expect(@flowConfig['8e74a6c0-55d6-11e5-bd83-1349dc09f6d6'].data).to.deep.equal {}

  describe '-> _buildLinks', ->
    beforeEach ->
      @sut = new ConfigurationGenerator {}, {UUID: @UUID}

    describe 'when one node is linked to another', ->
      beforeEach ->
        links = [
          from: 'some-node-uuid'
          to: 'some-other-node-uuid'
        ]

        flowConfig =
          'some-node-uuid':
            config:
              id: 'some-node-uuid'
              nanocyte:
                type: 'nanocyte-node-fluff'
                composedOf:
                  'fluff-1':
                    type: 'nanocyte-node-fluff'
                    linkedToNext: true
          'some-other-node-uuid':
            config:
              id: 'some-other-node-uuid'
              nanocyte:
                type: 'nanocyte-node-fluff'
                composedOf:
                  'fluff-1':
                    type: 'nanocyte-node-fluff'
                    linkedToPrev: true

        @UUID.v1.onCall(0).returns 'some-node-instance-uuid'
        @UUID.v1.onCall(1).returns 'some-other-node-instance-uuid'
        @result = @sut._buildLinks links, flowConfig

      it 'should set the flow links on the router', ->
        links =
          'some-node-instance-uuid':
            type: 'nanocyte-node-fluff'
            linkedTo: ['some-other-node-instance-uuid']
          'some-other-node-instance-uuid':
            type: 'nanocyte-node-fluff'
            linkedTo: []
          'engine-output':
            type: 'engine-output'
            linkedTo: []
          'engine-data':
            type: 'engine-data'
            linkedTo: []
          'engine-debug':
            type: 'engine-debug'
            linkedTo: []
          'engine-pulse':
            type: 'engine-pulse'
            linkedTo: []

        expect(@result).to.deep.equal links

    describe 'when a different node is linked to another', ->
      beforeEach ->
        links = [
          from: 'some-other-node-uuid'
          to: 'yet-some-other-node-uuid'
        ]

        flowConfig =
          'some-other-node-uuid':
            config:
              id: 'some-other-node-uuid'
              nanocyte:
                type: 'nanocyte-node-tuff'
                composedOf:
                  'tuff-2':
                    type: 'nanocyte-node-tuff'
                    linkedToNext: true
          'yet-some-other-node-uuid':
            config:
              id: 'some-other-node-uuid'
              nanocyte:
                type: 'nanocyte-node-tuff'
                composedOf:
                  'tuff-2':
                    type: 'nanocyte-node-tuff'
                    linkedToPrev: true

        @UUID.v1.onCall(0).returns 'some-other-node-instance-uuid'
        @UUID.v1.onCall(1).returns 'yet-some-other-node-instance-uuid'
        @result = @sut._buildLinks links, flowConfig

      it 'should set the flow links on the router', ->
        links =
          'some-other-node-instance-uuid':
            type: 'nanocyte-node-tuff'
            linkedTo: ['yet-some-other-node-instance-uuid']
          'yet-some-other-node-instance-uuid':
            type: 'nanocyte-node-tuff'
            linkedTo: []
          'engine-output':
            type: 'engine-output'
            linkedTo: []
          'engine-data':
            type: 'engine-data'
            linkedTo: []
          'engine-debug':
            type: 'engine-debug'
            linkedTo: []
          'engine-pulse':
            type: 'engine-pulse'
            linkedTo: []

        expect(@result).to.deep.equal links

    describe 'when one node is linked to two nodes', ->
      beforeEach ->
        links = [
          from: 'some-node-uuid'
          to: 'some-other-node-uuid'
        ,
          from: 'some-node-uuid'
          to: 'another-node-uuid'
        ]

        flowConfig =
          'some-node-uuid':
            config:
              id: 'some-node-uuid'
              nanocyte:
                type: 'nanocyte-node-fluff'
                composedOf:
                  'fluff-1':
                    type: 'nanocyte-node-fluff'
                    linkedToNext: true
          'some-other-node-uuid':
            config:
              id: 'some-other-node-uuid'
              nanocyte:
                type: 'nanocyte-node-fluff'
                composedOf:
                  'fluff-1':
                    type: 'nanocyte-node-fluff'
                    linkedToPrev: true
          'another-node-uuid':
            config:
              id: 'another-node-uuid'
              nanocyte:
                type: 'nanocyte-node-fluff'
                composedOf:
                  'fluff-1':
                    type: 'nanocyte-node-fluff'
                    linkedToPrev: true

        @UUID.v1.onCall(0).returns 'some-node-instance-uuid'
        @UUID.v1.onCall(1).returns 'some-other-node-instance-uuid'
        @UUID.v1.onCall(2).returns 'another-node-instance-uuid'
        @result = @sut._buildLinks links, flowConfig

      it 'should set the flow links on the router', ->
        links =
          'some-node-instance-uuid':
            type: 'nanocyte-node-fluff'
            linkedTo: ['some-other-node-instance-uuid', 'another-node-instance-uuid']
          'some-other-node-instance-uuid':
            linkedTo: []
            type: 'nanocyte-node-fluff'
          'another-node-instance-uuid':
            linkedTo: []
            type: 'nanocyte-node-fluff'
          'engine-output':
            type: 'engine-output'
            linkedTo: []
          'engine-data':
            type: 'engine-data'
            linkedTo: []
          'engine-debug':
            type: 'engine-debug'
            linkedTo: []
          'engine-pulse':
            type: 'engine-pulse'
            linkedTo: []

        expect(@result).to.deep.equal links

    describe 'when two nodes are linked to two nodes', ->
      beforeEach ->
        links = [
          from: 'some-node-uuid'
          to: 'some-other-node-uuid'
        ,
          from: 'some-node-uuid'
          to: 'another-node-uuid'
        ,
          from: 'some-different-node-uuid'
          to: 'some-other-node-uuid'
        ,
          from: 'some-different-node-uuid'
          to: 'another-node-uuid'
        ]

        flowConfig =
          'some-node-uuid':
            config:
              id: 'some-node-uuid'
              nanocyte:
                type: 'nanocyte-node-fluff'
                composedOf:
                  'fluffy-1':
                    type: 'nanocyte-node-fluff'
                    linkedToNext: true
          'some-other-node-uuid':
            config:
              id: 'some-other-node-uuid'
              nanocyte:
                type: 'nanocyte-node-stuff'
                composedOf:
                  'stuffy-1':
                    type: 'nanocyte-node-stuff'
                    linkedToPrev: true
          'some-different-node-uuid':
            config:
              id: 'some-different-node-uuid'
              nanocyte:
                type: 'nanocyte-node-ruff'
                composedOf:
                  'ruffy-1':
                    type: 'nanocyte-node-ruff'
                    linkedToNext: true
          'another-node-uuid':
            config:
              id: 'another-node-uuid'
              nanocyte:
                type: 'nanocyte-node-buff'
                composedOf:
                  'buffy-1':
                    type: 'nanocyte-node-buff'
                    linkedToPrev: true

        @UUID.v1.onCall(0).returns 'some-node-instance-uuid'
        @UUID.v1.onCall(1).returns 'some-other-node-instance-uuid'
        @UUID.v1.onCall(2).returns 'some-different-node-instance-uuid'
        @UUID.v1.onCall(3).returns 'another-node-instance-uuid'
        @result = @sut._buildLinks links, flowConfig

      it 'should set the flow links on the router', ->
        links =
          'some-node-instance-uuid':
            type: 'nanocyte-node-fluff'
            linkedTo: ['some-other-node-instance-uuid', 'another-node-instance-uuid']
          'some-other-node-instance-uuid':
            type: 'nanocyte-node-stuff'
            linkedTo: []
          'some-different-node-instance-uuid':
            type: 'nanocyte-node-ruff'
            linkedTo: ['some-other-node-instance-uuid', 'another-node-instance-uuid']
          'another-node-instance-uuid':
            linkedTo: []
            type: 'nanocyte-node-buff'
          'engine-output':
            type: 'engine-output'
            linkedTo: []
          'engine-data':
            type: 'engine-data'
            linkedTo: []
          'engine-debug':
            type: 'engine-debug'
            linkedTo: []
          'engine-pulse':
            type: 'engine-pulse'
            linkedTo: []

        expect(@result).to.deep.equal links

    describe 'when one node is linked to a virtual node', ->
      beforeEach ->
        links = []

        flowConfig =
          'some-node-uuid':
            config:
              id: 'some-node-uuid'
              nanocyte:
                type: 'nanocyte-node-debug'
                composedOf:
                  'debug-1':
                    linkedToOutput: true
                    type: 'nanocyte-node-debug'

        @UUID.v1.onCall(0).returns 'some-node-instance-uuid'
        @result = @sut._buildLinks links, flowConfig

      it 'should set the flow links on the router', ->
        links =
          'some-node-instance-uuid':
            type: 'nanocyte-node-debug'
            linkedTo: ['engine-output', 'engine-pulse']
          'engine-output':
            type: 'engine-output'
            linkedTo: []
          'engine-data':
            type: 'engine-data'
            linkedTo: []
          'engine-debug':
            type: 'engine-debug'
            linkedTo: []
          'engine-pulse':
            type: 'engine-pulse'
            linkedTo: []

        expect(@result).to.deep.equal links

    describe 'when debug is set to true', ->
      beforeEach ->
        links = []

        flowConfig =
          'some-node-uuid':
            config:
              id: 'some-node-uuid'
              debug: true
              nanocyte:
                type: 'nanocyte-node-bar'
                composedOf:
                  'bar-1':
                    type: 'nanocyte-node-bar'


        @UUID.v1.onCall(0).returns 'some-node-instance-uuid'
        @result = @sut._buildLinks links, flowConfig

      it 'should set the flow links on the router', ->
        links =
          'some-node-instance-uuid':
            type: 'nanocyte-node-bar'
            linkedTo: ['engine-debug']
          'engine-output':
            type: 'engine-output'
            linkedTo: []
          'engine-data':
            type: 'engine-data'
            linkedTo: []
          'engine-debug':
            type: 'engine-debug'
            linkedTo: []
          'engine-pulse':
            type: 'engine-pulse'
            linkedTo: []

        expect(@result).to.deep.equal links

    describe 'when linkedToOutput', ->
      beforeEach ->
        links = []

        flowConfig =
          'some-node-uuid':
            config:
              id: 'some-node-uuid'
              nanocyte:
                type: 'nanocyte-node-bar'
                composedOf:
                  'bar-1':
                    type: 'nanocyte-node-bar'
                    linkedToOutput: true

        @UUID.v1.onCall(0).returns 'some-node-instance-uuid'
        @result = @sut._buildLinks links, flowConfig

      it 'should set the flow links on the router', ->
        links =
          'some-node-instance-uuid':
            type: 'nanocyte-node-bar'
            linkedTo: ['engine-output', 'engine-pulse']
          'engine-output':
            type: 'engine-output'
            linkedTo: []
          'engine-data':
            type: 'engine-data'
            linkedTo: []
          'engine-debug':
            type: 'engine-debug'
            linkedTo: []
          'engine-pulse':
            type: 'engine-pulse'
            linkedTo: []

        expect(@result).to.deep.equal links

    describe 'when linkedToData', ->
      beforeEach ->
        links = []

        flowConfig =
          'some-node-uuid':
            config:
              id: 'some-node-uuid'
              nanocyte:
                type: 'nanocyte-node-save-me'
                composedOf:
                  'save-me-1':
                    type: 'nanocyte-node-save-me'
                    linkedToData: true

        @UUID.v1.onCall(0).returns 'some-node-instance-uuid'

        @result = @sut._buildLinks links, flowConfig

      it 'should set the flow links on the router', ->
        links =
          'some-node-instance-uuid':
            type: 'nanocyte-node-save-me'
            linkedTo: ['engine-data']
          'engine-output':
            type: 'engine-output'
            linkedTo: []
          'engine-data':
            type: 'engine-data'
            linkedTo: []
          'engine-debug':
            type: 'engine-debug'
            linkedTo: []
          'engine-pulse':
            type: 'engine-pulse'
            linkedTo: []

        expect(@result).to.deep.equal links

    describe 'when linkedToNext', ->
      beforeEach ->
        links = [
          from: 'some-trigger-uuid'
          to: 'some-throttle-uuid'
        ,
          from: 'some-throttle-uuid'
          to: 'some-debug-uuid'
        ]

        flowConfig =
          'some-trigger-uuid':
            config:
              id: 'some-trigger-uuid'
              nanocyte:
                type: 'nanocyte-node-trigger'
                composedOf:
                  'trigger-1':
                    type: 'nanocyte-node-trigger'
                    linkedToInput: true
                    linkedToNext: true
          'some-throttle-uuid':
            config:
              id: 'some-throttle-uuid'
              nanocyte:
                type: 'nanocyte-node-throttle'
                composedOf:
                  'throttle-push-1':
                    type: 'nanocyte-node-throttle-push'
                    linkedToData: true
                    linkedToPrev: true
                  'throttle-pop-1':
                    type: 'nanocyte-node-throttle-pop'
                    linkedTo: ['throttle-emit-1']
                    linkedToInput: true
                    linkedToData: true
                  'throttle-emit-1':
                    type: 'nanocyte-node-throttle-emit'
                    linkedToInput: true
                    linkedToNext: true
          'some-debug-uuid':
            config:
              id: 'some-debug-uuid'
              debug: true
              nanocyte:
                type: 'nanocyte-node-debug'
                composedOf:
                  'debug-1':
                    type: 'nanocyte-node-debug'
                    linkedToPrev: true

        @UUID.v1.onCall(0).returns 'trigger-instance-uuid'
        @UUID.v1.onCall(1).returns 'throttle-push-instance-uuid'
        @UUID.v1.onCall(2).returns 'throttle-pop-instance-uuid'
        @UUID.v1.onCall(3).returns 'throttle-emit-instance-uuid'
        @UUID.v1.onCall(4).returns 'debug-instance-uuid'

        @result = @sut._buildLinks links, flowConfig

      it 'should set the flow links on the router', ->
        links =
          'some-trigger-uuid':
            linkedTo: ['trigger-instance-uuid']
            type: 'engine-input'
          'trigger-instance-uuid':
            linkedTo: ['throttle-push-instance-uuid']
            type: 'nanocyte-node-trigger'
          'some-throttle-uuid':
            type: 'engine-input'
            linkedTo: ['throttle-pop-instance-uuid', 'throttle-emit-instance-uuid']
          'throttle-push-instance-uuid':
            type: 'nanocyte-node-throttle-push'
            linkedTo: ['engine-data']
          'throttle-pop-instance-uuid':
            type: 'nanocyte-node-throttle-pop'
            linkedTo: ['throttle-emit-instance-uuid', 'engine-data']
          'throttle-emit-instance-uuid':
            type: 'nanocyte-node-throttle-emit'
            linkedTo: ['debug-instance-uuid']
          'debug-instance-uuid':
            type: 'nanocyte-node-debug'
            linkedTo: ['engine-debug']
          'engine-output':
            type: 'engine-output'
            linkedTo: []
          'engine-data':
            type: 'engine-data'
            linkedTo: []
          'engine-debug':
            type: 'engine-debug'
            linkedTo: []
          'engine-pulse':
            type: 'engine-pulse'
            linkedTo: []

        expect(@result).to.deep.equal links
