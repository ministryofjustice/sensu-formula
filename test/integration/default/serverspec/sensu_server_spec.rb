require 'serverspec'
require 'net/http'
require 'uri'

set :backend, :exec

set :path, '/sbin:/usr/local/sbin:$PATH'

describe "sensu server setup" do

  sensu_conf = %w(redis.json rabbitmq.json api.json handlers.json).map{|c| "/etc/sensu/conf.d/" + c}
  sensu_conf.each do |f|
    describe file(f) do
      it {should be_file}
    end
  end

  describe file("/etc/apparmor.d/opt.sensu.embedded.bin.sensu-server") do
    it {should be_file}
  end

  describe service("sensu-server") do
    it {should be_enabled}
    it {should be_running}
  end

  describe file("/etc/apparmor.d/opt.sensu.embedded.bin.sensu-api") do
    it {should be_file}
  end

  describe service("sensu-api") do
    it {should be_enabled}
    it {should be_running}
  end

end
