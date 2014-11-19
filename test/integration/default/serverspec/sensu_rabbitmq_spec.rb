require 'serverspec'
require 'net/http'
require 'uri'

set :backend, :exec

set :path, '/sbin:/usr/local/sbin:$PATH'

describe "sensu rabbitmq setup" do
  rabbitmq = {
    "host" => "localhost",
    "port" => 5672,
    "user" => "sensu",
    "passwd" => "sensu",
    "vhost" => "/sensu"
  }

  describe package("rabbitmq-server") do
    it { should be_installed }
  end

  describe service("rabbitmq-server") do
    it { should be_enabled }
    it { should be_running }
  end

  describe port(rabbitmq["port"]) do
    it { should be_listening }
  end

  describe command("rabbitmqctl status") do
    its(:exit_status) { should eq 0 }
  end

  describe command("rabbitmqctl list_users|grep -q #{rabbitmq["user"]}") do
    its(:exit_status) { should eq 0 }
  end

  describe command("rabbitmqctl list_vhosts|grep -q #{rabbitmq["vhost"]}") do
    its(:exit_status) { should eq 0 }
  end
end
