#!/usr/bin/env ruby

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'hipchat'
require 'timeout'

class HipChatNotif < Sensu::Handler

  def event_name
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def handle
    apiversion = settings["hipchat"]["apiversion"] || 'v1'
    hipchatmsg = HipChat::Client.new(settings["hipchat"]["apikey"], :api_version => apiversion)
    # Create an array of rooms form the room config entry
    # If this is a string, we get an array of one entry,
    # If its an array, we get that back, keeping back-compatibility
    rooms = Array(settings["hipchat"]["room"])
    from = settings["hipchat"]["from"] || 'Sensu'

    grafana_base = settings["hipchat"].fetch("grafana_base", '')
    playbook = @event["check"].fetch("playbook", '')
    metric_name = @event["check"].fetch("metric_name", '')
    metric_prefix = @event['client'].fetch('metric_prefix', '')
    message = @event['check']['notification'] || @event['check']['output']

    # If the playbook attribute exists and is a URL, "[<a href='url'>playbook</a>]" will be output.
    # To control the link name, set the playbook value to the HTML output you would like.
    unless playbook.empty?
      begin
        uri = URI.parse(playbook)
        if %w( http https ).include?(uri.scheme)
          message << "  [<a href='#{playbook}'>Playbook</a>]"
        else
          message << "  Playbook:  #{playbook}"
        end
      rescue
        message << "  Playbook:  #{playbook}"
      end
    end

    unless grafana_base.empty?
      unless metric_name.empty?
        full_target = metric_name.sub(':::metric_prefix:::', metric_prefix)
        uri = URI.parse(grafana_base + "targets=" + URI.encode(full_target).gsub(',', '%2C'))
        message << "  [<a href='#{uri.to_s}'>Graph</a>]"
      end
    end

    begin
      timeout(3) do
        if @event['action'].eql?("resolve")
          rooms.each do |tmp_room|
            hipchatmsg[tmp_room].send(from, "RESOLVED - [#{event_name}] - #{message}.", :color => 'green')
          end
        else
          rooms.each do |tmp_room|
            hipchatmsg[tmp_room].send(from, "ALERT - [#{event_name}] - #{message}.", :color => @event['check']['status'] == 1 ? 'yellow' : 'red', :notify => true)
          end
        end
      end
    rescue Timeout::Error
      puts "hipchat -- timed out while attempting to message #{room}"
    end
  end

end
