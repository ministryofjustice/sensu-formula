## Version 5.2.x

* Fixed bug in the URL assembly for hipchat messages. 
  The Graph link in the hipchat message was broken.

* Increased alert threshold for NTP offset empty datasets 
  from 20 mins to 6hr, after getting spurious noisy 
  intermittent alerts on PVB.

## Version 5.2.1

* Fix sensu handlers.json template to allow multiple hipchat rooms using the 
  correct json syntax

## Version 5.2.0

* Increased default ntp offset alert threshold from 10 to 20 mins, to reduce
  redundant alert noise
* Extend hipchat handler to be able to send alerts to multiple rooms at once

  Simple make sensue:notify:hipchat_roomname an array and it will send it to
  all those rooms

## Version 5.1.4

* Add `ps` and `sh` to sensu-client apparmor profile to silence normal
  behavior

## Version 5.1.3

* Restart sensu-api as well as sensu-server when checks change

## Version 5.1.2

* Restart sensu-server when checks are removed as well as added

## Version 5.1.1

* Add a collectd script to graph redis process information (memory, cpu, etc)

## Version 5.1.0

* Extend check-elastic.rb to run count/threshold based checks too.

## Version 5.0.1

* Fix syntax error in handlers.json

## Version 5.0.0

* Remove pagerduty from default handlers
* Upgrade Uchiwa to 0.7.0-1
* Move all checks to map.jinja, this makes them configurable from the pillar.

## Version 4.5.2

* Move disk-space check to map.jinja so that it is overrideable in pillar.

## Version 4.5.1

* Add a new handler for sending selected alerts to the 2nd line support dashboard.

## Version 4.5.0

* Add 'Graph' link to integrate Grafana with hipchat notifications
* Can now have graphite checks which check the value is in a min/max range.

## Version 4.4.4

* Remove supervisor dependency
* Add ability to use the mailer handler from the community notification plugins.

## Version 4.4.3

* Sets the correct permissions on the plugins, so that only sensu can execute.

## Version 4.4.2

* Fix uchiwa pin for Trusty

## Version 4.4.1

* Sensu logging level is configurable
* Fix uchiwa order

## Version 4.4.0

* Sensu checks can now be provided by pillar data.
* Playbook for apparmor check, resolves #42
* Fix to allow standalone checks to be used again
* Allow sensu-embedded gems to be installed
* Silence apparmor message about 'sh'

## Version 4.3.0

* Upgrade Uchiwa to 0.3 (golang version)
* Update nginx conf to allow websockets over proxy.

## Version 4.2.0

* Prevent graphite-data.rb from throwing NilClass error on bad target/no data
* Uchiwa locked at 0.2.4 due to Websockets issue, but code present to upgrade to 0.3
* Upgrade sensu to 0.13.1-1

## Version 4.1.1

* Pin uchiwa for Ubuntu 12.04

## Version 4.1.0

* Let us specify a more exact process pattern to check for
* Allow passing through subscribers, handlers and all other parameters from
  sensu_check_graphite and sensu_check_proc down to the base sensu_check
* Improve docs

## Version 4.0.0

* **BREAKING** changes, see UPGRADING.md Move to sensu version 0.13.1 and uchiwa dashboard.

## Version 3.3.1

* Allow defining subscribers on graphite checks.

## Version 3.3.0

* Fixes to ensure sensu-server/sensu-client restarted on update
* Add swap-out graphite check
* Increase thesholds for swap-used check to reflect addition of swap-out
* Add Playbooks for swap-used and swap-out checks
* Add an alert on ntp clock drift to make sure time of all boxes is accurate

## Version 3.2.2

* Pagerduty should only send critical alerts
* Add occurences to check macro, set graphite checks to 2 occurrences.

## Version 3.2.1

* Fix apparmor profile for various new checks.
* Change apparmor to use generic elastic search check

## Version 3.2.0

* New plugin to check elastic search for user specified query.

  This lets us raise alerts based on log lines. See help in
  sensu/files/plugins/check-elastic.rb for usage

* Fix apparmor profile for sensu-server
* Add pillar entry to change hipchat api version used in sending notifications

## Version 3.1.1

* Pin sensu version for old dashboard service to work. (temp fix)

## Version 3.1.0

* Check JSON definitions only get installed on the server, no longer the
  client.
* Set subscriptions based on salt roles. Note your roles must be in a list!
* Included a new plugin to check backlog on unix sockets.

## Version 3.0.1

* Fix RabbitMQ start ordering

## Version 3.0.0

* Replace absolute disk space free check with one that checks percent in use
* Replace absolute swap check with one that checks percent used.
* Add apparmor profiles for sensu processes (client,api,dashboard and server)

## Version 2.2.0

* Allow graphite host to be specified in the pillar
* Allow check limits for graphite checks to be specified from pillar values

## Version 2.1.5

* Fix typo introduced in v2.1.4

## Version 2.1.4

* Be explicit about the permissions of the files we managed.

  Without this you could end up with a broken configuration depending on the
  umask of the user you run `salt-call` as.

## Version 2.1.3

* Ensure that /etc/salt/conf.d/checks is managed idempotently. Incremental
  runs of highstate will not incorrectly mark all files as changed.
* Pin community-plugins to a git commit instead of just master. This can
  be overridden by pillar var defined in map.jinja

## Version 2.1.2

* Fix: redphone and hipchat gems are now correctly installed in embedded
  ruby when pagerduty/hipchat integration is enabled
* Changed the Hipchat API to v1 to avoid the API key being associated
  with a person
* Removed additional subscriptions based on roles. This is not used at
  present and causes a failure on machines where roles are not defined

## Version 2.1.1

* Ensure all old checks get deleted by setting 'clean:True' on directory

## Version 2.1.0

* Added support for email, hipchat and pagerduty notification (see README)
* Moved notification pillar values to sensu.notify.*
* Tidied up require/watch logic on server/client setup

## Version 2.0.0

* Moved sensu community plugins so they are only available from
  `/etc/sensu/community` (previously was in `/etc/sensu/plugins`). **Breaking
  Change**
* Plugins are installed from `sensu/files/plugins/` in this formula into
  `/etc/sensu/plugins` directory.
* Added custom graphite plugin based on original community plugin
* Modified most of the existing checks to use graphite metrics to ensure alerts
  and metrics are drawing data from the same source
* Added client checks for cron and collectd processes are running

## Version 1.0.3

* Cleanup from PVB codebase

## Version 1.0.2

* Ensure /etc/sensu is owned by sensu and mode 700

## Version 1.0.1

* Updated rabbitmq formula dependency to 1.0.1

## Version 1.0.0

* Initial checkin

