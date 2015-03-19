#!/usr/bin/env ruby

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'net/http'
require 'json'
require 'uri'


class Level2SupportNotifier < Sensu::Handler


  def event_name
    @event['client']['name'] + '::' + @event['check']['name']
  end

  def handle
    remote_url = settings["level-2-support"]["url"]
  	@uri = URI(remote_url)
    response = Net::HTTP.post_form(@uri, {'event' => @event.to_json} )
    # need to handle  non-200 responses somehow
  end

end





