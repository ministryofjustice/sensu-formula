require 'serverspec'
require 'net/http'
require 'uri'

set :backend, :exec

set :path, '/sbin:/usr/local/sbin:$PATH'

describe "sensu uchiwa setup" do
  uchiwa_pkg = {
    "name" => "uchiwa",
    "version" => "0.3.2-1"
  }

  describe package(uchiwa_pkg["name"]) do
    it {should be_installed.with_version(uchiwa_pkg["version"])}
  end

  describe user("uchiwa") do
    it { should exist }
    it { should belong_to_group "sensu" }
  end

  describe file("/etc/init/uchiwa.conf") do
    it {should be_file}
  end

  describe file("/etc/sensu/uchiwa.json") do
    it {should be_file}
    it {should be_owned_by "uchiwa"}
    it {should be_grouped_into "uchiwa"}
  end

  describe file("/etc/apparmor.d/opt.uchiwa.embedded.bin.node") do
    it {should be_file}
  end

  %w(uchiwa nginx).each do |s|
    describe service(s) do
      it {should be_enabled}
      it {should be_running}
    end
  end

  [3000, 80].each do |p|
    describe port(p) do
      it { should be_listening }
    end

    describe "Uchiwa http #{p} health" do
      uri = URI.parse("http://localhost:#{p}/health/uchiwa")
      resp = Net::HTTP.get_response(uri)
      it "should be healthy" do
        resp.code == 200
      end
    end
  end

  describe file("/etc/nginx/conf.d/sensu.conf") do
    it {should be_file}
    it {should be_owned_by "root"}
    it {should be_grouped_into "root"}
    its(:content) { should match /localhost:3000/}
  end
 
end
