ChannelConfig = require '../src/channel-config'
{EventEmitter} = require 'events'

describe 'ChannelConfig', ->
  beforeEach ->
    @downloader = new EventEmitter
    @s3client = downloadFile: sinon.spy(=> @downloader)
    @jsonfile = readFile: sinon.stub()
    @sut = new ChannelConfig {},
      s3client: @s3client
      jsonfile: @jsonfile

  describe '-> fetch', ->
    describe 'when called', ->
      beforeEach ->
        @callback = sinon.spy()
        @sut.fetch @callback

      it 'should call s3.downloadFile', ->
        expect(@s3client.downloadFile).to.have.been.calledWith
          localFile: './channels.json'
          s3Params:
            Bucket: 'octoblu-channels'
            Key:    'channels.json'

      it 'should NOT YET call @jsonfile.readFile', ->
        expect(@jsonfile.readFile).not.to.have.been.called #yet #soon

      describe 'when the downloader emits an error', ->
        beforeEach ->
          @mahError = new Error 'download failure'
          @downloader.emit 'error', @mahError

        it 'should call the callback with the error', ->
          expect(@callback).to.have.been.calledWith @mahError

      describe 'when the downloader completes', ->
        beforeEach ->
          @downloader.emit 'end'

        it 'should read the file', ->
          expect(@jsonfile.readFile).to.have.been.calledWith './channels.json'

        describe 'when readFile works', ->
          beforeEach ->
            @jsonfile.readFile.yield null, {"exasperation":"I-cannot-freaking-believe-this"}

          it 'should set @sut._channels', ->
            expect(@sut._channels).to.deep.equal exasperation: "I-cannot-freaking-believe-this"

          it 'should call the callback without an error', ->
            expect(@callback).to.have.been.called
            expect(@callback.firstArg).not.to.exist

        describe 'when readFile no worky', ->
          beforeEach ->
            @goredThenDevouredError = new Error 'Gored, then devoured'
            @jsonfile.readFile.yield @goredThenDevouredError

          it 'should yield the error', ->
            expect(@callback).to.have.been.calledWith @goredThenDevouredError

  describe '-> get', ->
    describe 'when fetch has not been called', ->
      beforeEach ->
        delete @sut._channels

      it 'should throw an exception', ->
        func = => @sut.get 'channel:red-dwarf'
        expect(func).to.throw 'Cannot call get before fetch'

    describe 'when fetch has been called', ->
      beforeEach ->
        @sut._channels = [{stellar: 'body', type: 'channel:red-dwarf'}]
        @result = @sut.get 'channel:red-dwarf'

      it 'should return a channel', ->
        expect(@result).to.deep.equal stellar: 'body', type: 'channel:red-dwarf'

    describe 'when fetch has really been called', ->
      beforeEach ->
        @sut._channels = [{'ice-cream': 'cone', type: 'channel:something-cold'}]
        @result = @sut.get 'channel:something-cold'

      it 'should return a channel', ->
        expect(@result).to.deep.equal 'ice-cream': 'cone', type: 'channel:something-cold'
