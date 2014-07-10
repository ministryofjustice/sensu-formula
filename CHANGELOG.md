## Version 3.x.x

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

