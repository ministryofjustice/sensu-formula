require 'serverspec'
require 'net/http'
require 'uri'

set :backend, :exec

set :path, '/sbin:/usr/local/sbin:$PATH'

describe "sensu redis setup" do

  describe service("redis-server") do
    it { should be_enabled }
    it { should be_running }
  end

  describe port(6379) do
    it { should be_listening }
  end

end
