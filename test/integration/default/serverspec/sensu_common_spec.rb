require 'serverspec'
require 'net/http'
require 'uri'

set :backend, :exec

set :path, '/sbin:/usr/local/sbin:$PATH'
