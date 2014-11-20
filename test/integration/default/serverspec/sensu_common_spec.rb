require 'serverspec'
require 'net/http'
require 'uri'

set :backend, :exec

set :path, '/sbin:/usr/local/sbin:$PATH'

describe "sensu setup" do
  sensu_pkg = {
    "name" => "sensu",
    "version" => "0.13.1-1"
  }

  describe package(sensu_pkg["name"]) do
    it {should be_installed.with_version(sensu_pkg["version"])}
  end

  describe file("/opt/sensu/embedded/bin/ruby") do
    it { should be_file }
    it { should be_executable }
  end

  describe file("/etc/default/sensu") do
    it {should be_file}
    it {should be_owned_by "root"}
    it {should be_grouped_into "root"}
    its(:content) { should match /^EMBEDDED_RUBY=true$/}
  end

  describe file("/etc/sensu") do
    it {should be_directory}
    it {should be_mode 750}
    it {should be_owned_by "sensu"}
    it {should be_grouped_into "sensu"}
  end

  describe file("/etc/sensu/conf.d/checks") do
    it {should be_directory}
  end
end
