_ = require 'lodash'
ConfigurationGenerator = require '../src/configuration-generator'
sampleFlow = require './data/sample-flow.json'

describe 'ConfigurationGenerator', ->
  describe '-> configure', ->
    beforeEach ->
      @sut = new ConfigurationGenerator sampleFlow
    describe 'when called', ->
      beforeEach (done) ->
        @sut.configure (@error, @flowConfig) => done()

      it 'should return a flow configuration with keys for all the nodes in the flow', ->
        expect(@flowConfig).to.contain.keys [
          '8a8da890-55d6-11e5-bd83-1349dc09f6d6'
          '8e74a6c0-55d6-11e5-bd83-1349dc09f6d6'
          '2cf457d0-57eb-11e5-99ea-11ac2aafbb8d'
        ]

      it 'should return a flow configuration with virtual nodes', ->
        expect(@flowConfig).to.contain.keys [
          'meshblu-input'
          'meshblu-output'
          'router'
          'start'
          'stop'
        ]

      it 'should return a flow configuration with the router, io, nodes in the flow and the virtual nodes', ->
        expect(@flowConfig).to.contain.keys [
          '8a8da890-55d6-11e5-bd83-1349dc09f6d6'
          '8e74a6c0-55d6-11e5-bd83-1349dc09f6d6'
          '2cf457d0-57eb-11e5-99ea-11ac2aafbb8d'
          'meshblu-input'
          'meshblu-output'
          'router'
          'start'
          'stop'
        ]

      it 'should set the flow links on the router', ->
        links = {
          '8a8da890-55d6-11e5-bd83-1349dc09f6d6': {
            type: 'nanocyte-node-trigger',
            linkedTo: ['8e74a6c0-55d6-11e5-bd83-1349dc09f6d6']
          },
          '8e74a6c0-55d6-11e5-bd83-1349dc09f6d6': {
            type: 'nanocyte-node-debug',
            linkedTo: ['meshblu-output']
          },
          '2cf457d0-57eb-11e5-99ea-11ac2aafbb8d': {
            type: 'nanocyte-node-interval',
            linkedTo: ['8e74a6c0-55d6-11e5-bd83-1349dc09f6d6']
          }
        }

        expect(@flowConfig.router.config).to.deep.equal links

      it 'should configure the debug node with the proper config', ->
        origNodeConfig = _.findWhere sampleFlow.nodes, id: '8e74a6c0-55d6-11e5-bd83-1349dc09f6d6'
        expect(@flowConfig['8e74a6c0-55d6-11e5-bd83-1349dc09f6d6'].config).to.deep.equal origNodeConfig

      it 'should configure the debug node with default data', ->
        expect(@flowConfig['8e74a6c0-55d6-11e5-bd83-1349dc09f6d6'].data).to.deep.equal {}

  describe '-> buildLinks', ->
    describe 'when one node is linked to another', ->
      beforeEach ->
        @sut = new ConfigurationGenerator links: [
          from: 'some-node-uuid'
          to: 'some-other-node-uuid'
        ]

        flowConfig =
          'some-node-uuid':
            config:
              id: 'some-node-uuid'
              class: 'fluff'

        @result = @sut.buildLinks flowConfig

      it 'should set the flow links on the router', ->
        links =
          'some-node-uuid':
            type: 'nanocyte-node-fluff'
            linkedTo: ['some-other-node-uuid']

        expect(@result).to.deep.equal links

    describe 'when a different node is linked to another', ->
      beforeEach ->
        @sut = new ConfigurationGenerator links: [
          from: 'some-other-node-uuid'
          to: 'yet-some-other-node-uuid'
        ]

        flowConfig =
          'some-other-node-uuid':
            config:
              id: 'some-other-node-uuid'
              class: 'tuff'

        @result = @sut.buildLinks flowConfig

      it 'should set the flow links on the router', ->
        links =
          'some-other-node-uuid':
            type: 'nanocyte-node-tuff'
            linkedTo: ['yet-some-other-node-uuid']

        expect(@result).to.deep.equal links

    describe 'when one node is linked to two nodes', ->
      beforeEach ->
        @sut = new ConfigurationGenerator links: [
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
              class: 'fluff'

        @result = @sut.buildLinks flowConfig

      it 'should set the flow links on the router', ->
        links =
          'some-node-uuid':
            type: 'nanocyte-node-fluff'
            linkedTo: ['some-other-node-uuid', 'another-node-uuid']

        expect(@result).to.deep.equal links

    describe 'when two nodes are linked to two nodes', ->
      beforeEach ->
        @sut = new ConfigurationGenerator links: [
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
              class: 'fluff'

          'some-different-node-uuid':
            config:
              id: 'some-different-node-uuid'
              class: 'ruff'

        @result = @sut.buildLinks flowConfig

      it 'should set the flow links on the router', ->
        links =
          'some-node-uuid':
            type: 'nanocyte-node-fluff'
            linkedTo: ['some-other-node-uuid', 'another-node-uuid']
          'some-different-node-uuid':
            type: 'nanocyte-node-ruff'
            linkedTo: ['some-other-node-uuid', 'another-node-uuid']

        expect(@result).to.deep.equal links

    describe 'when one node is linked to a virtual node', ->
      beforeEach ->
        @sut = new ConfigurationGenerator links: []

        flowConfig =
          'some-node-uuid':
            config:
              id: 'some-node-uuid'
              class: 'debug'

        @result = @sut.buildLinks flowConfig

      it 'should set the flow links on the router', ->
        links =
          'some-node-uuid':
            type: 'nanocyte-node-debug'
            linkedTo: ['meshblu-output']

        expect(@result).to.deep.equal links
