require 'serverspec'
require 'net/http'
require 'uri'

set :backend, :exec

set :path, '/sbin:/usr/local/sbin:$PATH'

describe "sensu server setup" do
  sensu_conf = %w(client.json rabbitmq.json).map{|c| "/etc/sensu/conf.d/" + c}
  sensu_conf.each do |f|
    describe file(f) do
      it {should be_file}
      it {should be_mode 644}
    end
  end

  describe file("/etc/sensu/plugins") do
    it {should be_directory}
    it {should be_mode 700}
    it {should be_owned_by "sensu"}
    it {should be_grouped_into "sensu"}
  end

  describe service("sensu-client") do
    it {should be_enabled}
    it {should be_running}
  end

end
