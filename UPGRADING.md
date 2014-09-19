sudo salt -C G@roles:monitoring.server service.stop sensu-dashboard
sudo salt \* state.highstate
sudo salt -C G@roles:monitoring.server service.restart sensu-server
sudo salt -C G@roles:monitoring.server service.restart sensu-api
sudo salt -C G@roles:monitoring.server cmd.run 'redis-cli -n 1 FLUSHDB'
sudo salt -C G@roles:monitoring.server service.restart uchiwa
