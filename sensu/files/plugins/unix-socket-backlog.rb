#!/usr/bin/env ruby
#
# Check unicorn backlog
# ===
#
# This plugin checks unicorn connection stats

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'raindrops'

class CheckUnixSocketData < Sensu::Plugin::Check::CLI

  option :socket,
    :description => 'Unix socket e.g. /var/run/unicorn.sock',
    :short => '-s SOCKET',
    :long => '--socket SOCKET',
    :required => true

  option :below,
    :description => 'warnings/critical if values below specified thresholds',
    :short => '-b',
    :long => '--below'

  option :help,
    :description => 'Show this message',
    :short => '-h',
    :long => '--help'

  option :warning,
    :description => 'Generate warning if given value is above received value',
    :short => '-w VALUE',
    :long => '--warn VALUE',
    :proc => proc{|arg| arg.to_i }

  option :critical,
    :description => 'Generate critical if given value is above received value',
    :short => '-c VALUE',
    :long => '--critical VALUE',
    :proc => proc{|arg| arg.to_i }

  def measure
    addr = [ config[:socket] ] 
    @stats = Raindrops::Linux.unix_listener_stats(addr)
    @stats[0].queued
  end

  # Run checks
  def run
    if config[:help]
      puts opt_parser if config[:help]
      exit
    end

    @data = measure
    check(:critical) || check(:warning)
    ok("Unix socket backlog value (#{@data})")
  end

  # type:: :warning or :critical
  # Return alert if required
  def check(type)
    if config[type]
      send(type, "Unix socket backlog value (#{@data}) [#{config[:socket]}]") if (below?(type) || above?(type))
    end
  end

  # Check if value is below defined threshold
  def below?(type)
    config[:below] && @data < config[type]
  end

  # Check is value is above defined threshold
  def above?(type)
    (!config[:below]) && (@data > config[type])
  end

end

