#!/usr/bin/env ruby
#
# Check redis logstash/beaver queue
# ===
#
# This plugin checks to see if there are excessive log alerts being generated in logstash/beaver

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'raindrops'
require 'redis'
require 'json'


class CheckRedisQueue < Sensu::Plugin::Check::CLI
  option :logcommand,
    :description => 'log command',
    :short => '-l log',
    :long => '--Log Command',
    :default => "logstash:beaver",
    :required => true

  option :host,
    :description => 'host',
    :short => '-o host',
    :long => '--Host',
    :default => "127.0.0.1",	
    :required => true

  option :port,
    :description => 'port',
    :short => '-p port',
    :long => '--Port',
    :default => 6379,      
    :required => true

  option :database,
    :description => 'database',
    :short => '-d database',
    :long => '--Database',
    :default => 0, 
    :required => true

  option :above,
    :description => 'warnings/critical if values below specified thresholds',
    :short => '-a',
    :long => '--above'

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
   # example -  redis = Redis.new(:host => "127.0.0.1", :port => 6379, :db => 0)
    redis = Redis.new(:host => (config[:host]), :port => (config[:port]), :db => (config[:database]))
   
   # example - redis.llen("logstash:beaver") 
    redis.llen(config[:logcommand])
  end

  # Run checks
  def run
    if config[:help]
      puts opt_parser if config[:help]
      exit
    end

    @data = measure
    check(:critical) || check(:warning)
    ok("Logstash queue value (#{@data})")
  end

  # type:: :warning or :critical
  # Return alert if required
  # Return alert if required
  def check(type)
    if config[type]
      send(type, "Logstash queue value (#{@data}) [#{config[:socket]}]") if (below?(type) || above?(type))
    end
  end

  # Check if value is above defined threshold
  def above?(type)
    config[:below] && @data < config[type]
  end

  # Check is value is below defined threshold
  def below?(type)
    (!config[:below]) && (@data > config[type])
  end
end

