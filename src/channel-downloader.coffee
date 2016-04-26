_                 = require 'lodash'
s3                = require 's3'
CHANNEL_S3_BUCKET = 'octoblu-channels'
CHANNEL_S3_KEY    = 'channels.json'

class ChannelDownloader
  constructor: ->
    @cached = false
    @etag = null
    @data = null
    @_checkEtag = _.throttle @_checkEtagImmediately, 60*1000*5, leading: true, trailing: false

  setOptions: (options) =>
    @s3client ?= s3.createClient
      s3Options:
        accessKeyId:     options.accessKeyId
        secretAccessKey: options.secretAccessKey

  update: (callback) =>
    @_checkEtag()
    return callback null, @data if @cached

    downloader = @s3client.downloadBuffer
      Bucket: CHANNEL_S3_BUCKET
      Key:    CHANNEL_S3_KEY

    downloader.on 'httpHeaders', (statusCode, headers) ->
      @etag = headers.etag

    downloader.on 'error', callback
    downloader.on 'end', (buffer) =>
      try
        @data = JSON.parse buffer
      catch error
        return callback error

      @cached = true
      callback null, @data

  _checkEtagImmediately: =>
    console.log {@cached}
    list = @s3client.listObjects
      s3Params:
        Bucket: CHANNEL_S3_BUCKET

    list.on 'data', (data) =>
      entry = _.find data.Contents, {'Key': 'channels.json'}
      return unless entry?
      console.log {@etag, entry: entry.ETag}
      return if @etag == entry.ETag
      @etag = entry.ETag
      @cached = false

module.exports = ChannelDownloader
