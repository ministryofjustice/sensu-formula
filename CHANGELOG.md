##

* Moved sensu community plugins so they are only available from /etc/sensu/community
* Added custom graphite plugin based on original community plugin
* Modified most of the existing checks to use graphite metrics to ensure alerts and
  metrics are drawing data from the same source
* Added client checks for cron and collectd

## Version 1.0.3

* Cleanup from PVB codebase

## Version 1.0.2

* Ensure /etc/sensu is owned by sensu and mode 700

## Version 1.0.1

* Updated rabbitmq formula dependency to 1.0.1

## Version 1.0.0

* Initial checkin

