## Version 3.x to 4.x

This takes you from sensu 0.12.x to 0.13.x which has API breaking changes. This requires a new dashboard and a flush of the redis database. Ensure that your redis database with index 1 is only used by sensu, then:

```
sudo salt -C G@roles:monitoring.server service.stop sensu-dashboard
sudo salt -C G@roles:monitoring.server service.stop sensu-api
sudo salt -C G@roles:monitoring.server service.stop sensu-server
sudo salt -C G@roles:monitoring.server cmd.run 'redis-cli -n 1 FLUSHDB'
sudo salt \* state.highstate
```

The new dashboard used is called [uchiwa](https://github.com/sensu/uchiwa)
