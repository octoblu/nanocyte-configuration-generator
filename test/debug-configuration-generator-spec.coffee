_ = require 'lodash'
nodeUuid = require 'node-uuid'

ConfigurationGenerator = require '../src/configuration-generator'
ConfigurationUtilities = require '../src/configuration-utilities'

sampleFlow = require './data/debug-sample-flow.json'
nodeRegistry = require "./data/node-registry"

describe.only 'DEBUG ConfigurationGenerator', ->
  beforeEach ->
    @request = get: sinon.stub()
    @channelConfig =
      fetch: sinon.stub()
      get: sinon.stub()

  describe '->configure', ->
    beforeEach ->
      options =
        meshbluJSON:
          server: 'some-server'

      dependencies =
        request: @request
        channelConfig: @channelConfig

      @sut = new ConfigurationGenerator options, dependencies

    describe 'when called', ->
      beforeEach (done) ->
        @request.get.yields null, {}, nodeRegistry
        @channelConfig.fetch.yields null

        options =
          flowData: sampleFlow
          flowToken: 'some-token'
          deploymentUuid: 'the-deployment-uuid'

        @sut.configure options, (error, flowConfig) =>
          @configurationUtilities = new ConfigurationUtilities flowConfig.router.config
          done()

      it 'should not link the debugged node directly to the previous node', ->
        equalsInputId = _.first(@configurationUtilities.findNanocytesByType 'equals-input').id
        triggerOutput = _.first(@configurationUtilities.findNanocytesByType 'trigger-output').nanocyte
        expect(triggerOutput.linkedTo).not.to.contain equalsInputId

      it 'should link a non-debugged node directly to the previous node', ->
        notEqualsInputId = _.first(@configurationUtilities.findNanocytesByType 'not-equals-input').id
        triggerOutput    = _.first(@configurationUtilities.findNanocytesByType 'trigger-output').nanocyte
        expect(triggerOutput.linkedTo).to.contain notEqualsInputId
