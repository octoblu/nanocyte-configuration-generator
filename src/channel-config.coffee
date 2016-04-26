_                 = require 'lodash'
ChannelDownloader = require './channel-downloader'

# outside the class so cache is maintained
Downloader = new ChannelDownloader

class ChannelConfig
  constructor: (options) ->
    Downloader.setOptions options

  get: (type) =>
    _.findWhere @_channels, type: type

  update: (callback) =>
    Downloader.update (error, @channels) =>
      callback error

module.exports = ChannelConfig
