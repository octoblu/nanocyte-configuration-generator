s3 = require 's3'
jsonfile = require 'jsonfile'
_ = require 'lodash'
CHANNEL_S3_BUCKET = 'octoblu-channels'
CHANNEL_S3_KEY    = 'channels.json'

class ChannelConfig
  constructor: (options, dependencies={}) ->
    {@s3client,@jsonfile} = dependencies

    @jsonfile ?= jsonfile
    @s3client ?= s3.createClient
      s3Options:
        accessKeyId:     options.accessKeyId
        secretAccessKey: options.secretAccessKey

  fetch: (callback) =>
    downloader = @s3client.downloadFile
      localFile: './channels.json'
      s3Params:
        Bucket: CHANNEL_S3_BUCKET
        Key:    CHANNEL_S3_KEY

    downloader.on 'error', callback
    downloader.on 'end',  =>
      @jsonfile.readFile './channels.json', (error, channels) =>
        return callback error if error?
        @_channels = channels
        callback()

  get: (type) =>
    throw new Error 'Cannot call get before fetch' unless @_channels?
    _.findWhere @_channels, type: type

module.exports = ChannelConfig
