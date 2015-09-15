ConfigurationGenerator = require '../src/configuration-generator'
sampleFlow = require './data/sample-flow.json'
describe 'ConfigurationGenerator', ->
  beforeEach ->
    @sut = new ConfigurationGenerator sampleFlow

  describe '-> configure', ->
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

      it 'should configure the debug mode with the proper config', ->
        beforeEach ->
          expect(@flowConfig['8e74a6c0-55d6-11e5-bd83-1349dc09f6d6'].config).to.deep.equal
