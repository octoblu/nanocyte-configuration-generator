{afterEach, beforeEach, context, describe, it} = global
{expect} = require 'chai'
sinon = require 'sinon'
enableDestroy = require 'server-destroy'

shmock                 = require 'shmock'
ConfigurationGenerator = require '../src/configuration-generator'

metadataRequestFlow    = require './data/metadata-request-flow.json'
metadataRequestFlow2    = require './data/metadata-request-flow-2.json'

nodeRegistry           = require './data/node-registry'


describe 'Configuring EngineOutput to insert metadata into messages', ->
  beforeEach (done) ->
    @meshblu = shmock done
    enableDestroy @meshblu

  afterEach (done) ->
    @meshblu.destroy done

  beforeEach ->
    @meshbluJSON =
      server: 'localhost'
      port: @meshblu.address().port
      uuid: 'brave-user'
      token: 'who-fears-no-breaking-changes'

    @request = get: sinon.stub().yields null, {}, nodeRegistry
    @channelConfig =
      update: sinon.stub().yields null
      get: sinon.stub().returns {}

  describe '->configure', ->
    beforeEach ->
      options = meshbluJSON: @meshbluJSON
      dependencies =
        request: @request
        channelConfig: @channelConfig

      @sut = new ConfigurationGenerator options, dependencies

    context 'generating configuration with devices that want metadata', ->
      beforeEach ->
        @meshblu
          .post '/search/devices'
          .send({
            uuid:
              $in: ['gimme-metadata', 'no-metadata-plz']
            'octoblu.flow.forwardMetadata': true
          })
          .reply(200, [uuid: 'gimme-metadata'])

      beforeEach ->
        @meshblu
          .post '/search/devices'
          .send({
            uuid:
              $in: ['gimme-metadata', 'no-metadata-plz']
            'schemas.version': '1.0.0'
          })
          .reply(200, [])

      beforeEach (done) ->
        @channelConfig.update.yields null
        options =
          flowData: metadataRequestFlow
          flowToken: 'some-token'
          deploymentUuid: 'the-deployment-uuid'

        @sut.configure options, (@error, @flowConfig) =>
          return done @error if @error?
          {@forwardMetadataTo} = @flowConfig['engine-output'].config
          done()

      it 'should configure engine-output with the uuids of devices that want metadata injected into their messages', ->
        expect(@forwardMetadataTo).to.deep.equal ['gimme-metadata']

    context 'generating configuration with devices that use new schemas', ->
      beforeEach ->
        @meshblu
          .post '/search/devices'
          .send({
            uuid:
              $in: ['gimme-metadata', 'no-metadata-plz']
            'octoblu.flow.forwardMetadata': true
          })
          .reply(200, [uuid: 'gimme-metadata'])

      beforeEach ->
        @meshblu
          .post '/search/devices'
          .send({
            uuid:
              $in: ['gimme-metadata', 'no-metadata-plz']
            'schemas.version': '1.0.0'
          })
          .reply(200, [uuid: 'gimme-metadata'])

      beforeEach (done) ->
        @channelConfig.update.yields null
        options =
          flowData: metadataRequestFlow
          flowToken: 'some-token'
          deploymentUuid: 'the-deployment-uuid'

        @sut.configure options, (@error, @flowConfig) =>
          return done @error if @error?
          @engineOutputConfig = @flowConfig['engine-output'].config
          done()

      it 'should configure engine-output with uuids of devices that do not want their output wrapped in a payload', ->
        expect(@engineOutputConfig.noPayloadForUsPlease).to.deep.equal ['gimme-metadata']

    context 'generating a configuration for a different flow', ->
      beforeEach ->
        @meshblu
          .post '/search/devices'
          .send({
            uuid:
              $in: ['new-channel-as-device-overlord', 'metadata-luddite', 'fifth-element']
            'octoblu.flow.forwardMetadata': true
          })
        .reply(200, [{uuid: 'new-channel-as-device-overlord'}, {uuid: 'fifth-element'}])

      beforeEach ->
        @meshblu
          .post '/search/devices'
          .send({
            uuid:
              $in: ['new-channel-as-device-overlord', 'metadata-luddite', 'fifth-element']
            'schemas.version': '1.0.0'
          })
          .reply(200, [])


      beforeEach (done) ->
        @channelConfig.update.yields null
        options =
          flowData: metadataRequestFlow2
          flowToken: 'some-token'
          deploymentUuid: 'the-deployment-uuid'

        @sut.configure options, (@error, @flowConfig) =>
          {@forwardMetadataTo} = @flowConfig['engine-output'].config
          done()

      it 'should configure engine-output with the uuids of devices that want metadata injected into their messages', ->
        expect(@forwardMetadataTo).to.deep.equal ['new-channel-as-device-overlord', 'fifth-element']

    context 'generating a configuration and something goes wrong with meshblu', ->
      beforeEach ->
        @meshblu
          .post '/search/devices'
          .reply 422

      beforeEach (done) ->
        @channelConfig.update.yields null
        options =
          flowData: metadataRequestFlow2
          flowToken: 'some-token'
          deploymentUuid: 'the-deployment-uuid'

        @sut.configure options, (@error) => done()

      it 'should configure engine-output with the uuids of devices that want metadata injected into their messages', ->
        expect(@error).to.exist
