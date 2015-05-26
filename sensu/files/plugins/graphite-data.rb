#!/usr/bin/env ruby
#
# Check graphite values
# ===
#
# This plugin checks values within graphite

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'json'
require 'open-uri'

class CheckGraphiteData < Sensu::Plugin::Check::CLI

  option :target,
    :description => 'Graphite data target',
    :short => '-t TARGET',
    :long => '--target TARGET',
    :required => true

  option :server,
    :description => 'Server host and port',
    :short => '-s SERVER:PORT',
    :long => '--server SERVER:PORT',
    :required => true

  option :username,
    :description => 'username for basic http authentication',
    :short => '-u USERNAME',
    :long => '--user USERNAME',
    :required => false

  option :password,
    :description => 'user password for basic http authentication',
    :short => '-p PASSWORD',
    :long => '--pass PASSWORD',
    :required => false

  option :passfile,
    :description => 'password file path for basic http authentication',
    :short => '-P PASSWORDFILE',
    :long => '--passfile PASSWORDFILE',
    :required => false

  option :warning,
    :description => 'Generate warning if given value is above received value. Or comma seperated range.',
    :short => '-w VALUE',
    :long => '--warn VALUE',
    :proc => proc{|arg| arg.split(',').map &:to_f }

  option :critical,
    :description => 'Generate critical if given value is above received value. Or comma separated range.',
    :short => '-c VALUE',
    :long => '--critical VALUE',
    :proc => proc{|arg| arg.split(',').map &:to_f }

  option :reset_on_decrease,
    :description => 'Send OK if value has decreased on any values within END-INTERVAL to END',
    :short => '-r INTERVAL',
    :long => '--reset INTERVAL',
    :proc => proc{|arg| arg.to_i }

  option :name,
    :description => 'Name used in responses',
    :short => '-n NAME',
    :long => '--name NAME',
    :default => "graphite check"

  option :allowed_graphite_age,
    :description => 'Allowed number of seconds since last data update (default: 60 seconds)',
    :short => '-a SECONDS',
    :long => '--age SECONDS',
    :default => 60,
    :proc => proc{|arg| arg.to_i }

  option :hostname_sub,
    :description => 'Character used to replace periods (.) in hostname (default: _)',
    :short => '-s CHARACTER',
    :long => '--host-sub CHARACTER'

  option :from,
    :description => 'Get samples starting from FROM (default: -10mins)',
    :short => '-f FROM',
    :long => '--from FROM',
    :default => "-10mins"

  option :below,
    :description => 'warnings/critical if values below specified thresholds',
    :short => '-b',
    :long => '--below'

  option :method,
    :description => "Method to use to aggregate the data returned from Graphite into a value to check: median(default), mean, max, min, last, penultimate",
    :short => '-m METHOD',
    :long => '--method METHOD',
    :default => 'median'

  option :help,
    :description => 'Show this message',
    :short => '-h',
    :long => '--help'
    
  option :pretty,
    :description => 'Make the output message pretty',
    :long => '--pretty'

  # Run checks
  def run
    if config[:help]
      puts opt_parser if config[:help]
      exit
    end

    if config[:method]
      unless self.methods.include?("method_#{config[:method]}".to_sym)
        unknown("#{name}: unsupported check method '#{config[:method]}', valid values are median(default), mean, max, min, last, penultimate")
      end
    end

    data = retrieve_data
    if data.empty?
      critical "Empty dataset retrieved for target '#{formatted_target}' - is the target valid?"
    elsif data.nil?
      critical "Nil dataset retrieved for target '#{formatted_target}'. This is probably a bug."
    else
      data.each_pair do |key, value|
        @value = value
        @data = value['data']
        check_age || check(:critical) || check(:warning)
      end
      ok("#{name} value okay (#{value_to_check(@data)})")
    end
  end

  # name used in responses
  def name
    base = config[:name]
    @formatted ? "#{base} (#{@formatted})" : base
  end

  # Check the age of the data being processed
  def check_age
    if (Time.now.to_i - @value['end']) > config[:allowed_graphite_age]
      critical "Graphite data age is past allowed threshold (#{config[:allowed_graphite_age]} seconds)"
    end
  end

  # grab data from graphite
  def retrieve_data
    unless @raw_data
      begin

        url = "http://#{config[:server]}/render?format=json&target=#{formatted_target}&from=#{config[:from]}"

        if (config[:username] && (config[:password] || config[:passfile]))
          if config[:passfile]
            pass = File.open(config[:passfile]).readline
          elsif config[:password]
            pass = config[:password]
          end
          handle = open(url, :http_basic_authentication =>["#{config[:username]}", pass.chomp])
        else # we don't have both username and password trying without
          handle = open(url)
        end

        @raw_data = JSON.parse(handle.gets)
        output = {}
        @raw_data.each do |raw|
          raw['datapoints'].delete_if{|v| v.first.nil? }
          next if raw['datapoints'].empty?
          target = raw['target']
          data = raw['datapoints'].map {|dp| Float(dp.first) }
          start = raw['datapoints'].first.last
          dend = raw['datapoints'].last.last
          step = ((dend - start) / raw['datapoints'].size.to_f).ceil
          output[target] = { 'target' => target, 'data' => data, 'start' => start, 'end' => dend, 'step' => step }
        end
        output
      rescue OpenURI::HTTPError
        unknown "Failed to connect to graphite server"
      rescue NoMethodError
        unknown "No data for time period and/or target"
      rescue Errno::ECONNREFUSED
        unknown "Connection refused when connecting to graphite server"
      rescue Errno::ECONNRESET
        unknown "Connection reset by peer when connecting to graphite server"
      rescue EOFError
        unknown "End of file error when reading from graphite server"
      rescue Exception => e
        unknown "An unknown error occured: #{e.inspect}"
      end
    end
  end

  # type:: :warning or :critical
  # Return alert if required
  def check(type)
    if config[type]
      if config[:pretty]
        checked_value = prettyValue(value_to_check(@data))
        alert_value = prettyValue(config[type][0])
        if config[type].length == 1
          send(type, "#{name} is above #{type} limit: #{checked_value} / #{alert_value}") if in_alert_range?(type)
        elsif config[type].length == 2
          alert_range_start = prettyValue(config[type][0])
          alert_range_end = prettyValue(config[type][1])
          send(type, "#{name} is outside of #{type} range: #{checked_value} [#{alert_range_start} -> #{alert_range_end}]") if in_alert_range?(type)
        end
      else
        send(type, "#{name} (#{value_to_check(@data)}) [#{@value['target']}]") if in_alert_range?(type)
      end
    end
  end

  # Attempt to format a value into a prettified version using best guesswork
  def prettyValue(raw_value)
    value = raw_value
    postfix = ''
    target = @value['target']

    if target.include?("asPercent")
      postfix = postfix + "%"
    end
    if raw_value.is_a?(Float)
      value = value.round(1)
    end

    return "#{value}#{postfix}"
  end
    
  # Check if value is below defined threshold
  def below?(type)
    config[:below] && value_to_check(@data) < config[type]
  end

  # Check is value is above defined threshold
  def above?(type)
    (!config[:below]) && (value_to_check(@data) > config[type]) && (!decreased?)
  end

  def in_alert_range?(type)
    #If warn/crit val is num then do above/below logic
    #Else its a range.
    if config[type].length == 1
      config[type] = config[type][0]
      (below?(type) || above?(type))
    elsif config[type].length == 2
      value_to_check(@data).between?(config[type][0], config[type][1])
    else
      unknown "Bad range specified for alert."
    end
  end

  # Check if values have decreased within interval if given
  def decreased?
    if config[:reset_on_decrease]
      slice = @data.slice(@data.size - config[:reset_on_decrease], @data.size)
      val = slice.shift until slice.empty? || val.to_f > slice.first
      !slice.empty?
    else
      false
    end
  end

  # Returns formatted target with hostname replacing any $ characters
  def formatted_target
    if config[:target].include?('$')
      require 'socket'
      @formatted = Socket.gethostbyname(Socket.gethostname).first.gsub('.', config[:hostname_sub] || '_')
      config[:target].gsub('$', @formatted)
    else
      URI.escape config[:target]
    end
  end

  def value_to_check(array)
    eval("method_#{config[:method]}(array)")
  end

  def method_median(array)
    return nil if array.empty?
    sorted = array.sort
    len = sorted.length
    (sorted[(len - 1) / 2] + sorted[len / 2]) / 2.0
  end

  def method_mean(array)
    return nil if array.empty?
    array.inject(:+) / Float(array.size)
  end

  def method_last(array)
    return nil if array.empty?
    array.last
  end

  def method_penultimate(array)
    array.pop
    return nil if array.empty?
    array.last
  end

  def method_min(array)
    return nil if array.empty?
    array.sort.first
  end

  def method_max(array)
    return nil if array.empty?
    array.sort.last
  end
end