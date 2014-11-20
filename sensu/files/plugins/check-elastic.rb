#!/usr/bin/env ruby

require 'rubygems'
require 'json'
require 'rest-client'
require 'sensu-plugin/check/cli'
require 'socket'

class ElasticSearchCheck < Sensu::Plugin::Check::CLI
  option  :es_proto, :short => '-o HTTP(S)', :long => '--es-proto HTTP(S)',
          :default => 'http'
  option  :es_host, :short => '-h ES_HOST', :long => '--es-host ES_HOST', 
          :default => 'localhost'
  option  :es_port, :short => '-p ES_PORT', :long => '--es-port ES_PORT',
          :default => '9200'
  option  :tag, :short => '-t tagname', :long => '--tag tagname',
          :default => 'apparmor'
  option  :range, :short => '-r range', :long => '--range range',
          :default => '10m'
  option  :handler, :short => '-l handler', :long => '--handler handler',
          :default => 'default'
  option  :result_key, :short => '-k result_key', :long => '--result-key result_key',
          :default => 'message'
  option  :query, :short => '-q query', :long => '--query query',
          :default => 'tags: rails'
  option  :out_string, :short => '-s out_string', :long => '--out-string out_string'

  DEFAULT_SIZE=1

  def get_data(size=DEFAULT_SIZE)
    today = Time.now.strftime('%Y.%m.%d')
    resource = "logstash-#{today}/_search?pretty&size=#{size}"
    query_data = {'query' => {
                    'filtered' => {
                      'query' => {
                        'query_string' =>  {
                          'query' => "#{config[:query]}"
                        }
                      }
                    }
                  }, 'filter' => {
                      'range'=> {
                        '@timestamp' => {
                          'gt' => "now-#{config[:range]}"
                        }
                      }
                    }
                }
              
    url = "#{config[:es_proto]}://#{config[:es_host]}:#{config[:es_port]}/#{resource}"
    # RestClient.log = 'stdout'
    r = RestClient.post url, JSON.generate(query_data), 
                {:content_type => :json, :accept => :json}
    JSON.parse(r)
  end

  def submit_alert(alert_string)
    s = TCPSocket.open('localhost', 3030)
    s.send alert_string, 0
    r_socks, w_socs, e_socks = IO.select([s], [], [], 10)
    res = ''
    if r_socks[0] == s
      res = s.recv_nonblock(1024)
    end
    s.close()

    if res != 'ok'
      return false
    end
    true
  end

  def run
    data = get_data
    hits =  data['hits']['total']
    err = 0
    success = 0    
    if hits > 0
      if hits > DEFAULT_SIZE
        data = get_data(hits)
      end
      for result in data['hits']['hits']
        hostname = result['_source']['host']
        details = result['_source'][config[:result_key]]
        if config[:out_string]
          out = config[:out_string]
        else
          out = "Check host for ES query string: #{config[:query]}"
        end
        handler = config[:handler].to_s.split(',')
        msg = JSON.generate({ 'name' => "#{config[:tag]}_#{hostname}",
          'status' => 2, 'output' => out,
          'handler' => handler })
        res = submit_alert(msg)

        if res == true
          success += 1
        else
          err += 1
        end
      end
      if err > 0 and success == 0
        critical "Failed to submit query results"
      elsif err >0 and success > 0
        warning "Failed to submit #{err} results. Successful submissions: #{success}"
      else
        ok "#{success} results submitted"
      end

    end
    ok "No new results"
  end
end
