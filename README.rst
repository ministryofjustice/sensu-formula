=======
sensu
=======

Install and configure sensu and some simple common checks (disk, memory etc.)

.. note::

    See the full `Salt Formulas installation and usage instructions
    <http://docs.saltstack.com/topics/conventions/formulas.html>`_.

Dependencies
============

Playbooks for checks are available in `docs/playbooks https://github.com/ministryofjustice/sensu-formula/tree/master/docs/playbooks/>`_

Dependencies
============

.. note::

   This formula has a dependency on the following salt formulas:

   `logstash <https://github.com/ministryofjustice/logstash-formula>`_

   `redis <https://github.com/ministryofjustice/redis-formula>`_

   `rabbitmq <https://github.com/ministryofjustice/rabbitmq-formula>`_

   `nginx <https://github.com/ministryofjustice/nginx-formula>`_


Available states and macros
===========================

.. contents::
    :local:

``server``
----------

Install sensu server, dashboard and api components talking against a local
rabbitmq cluster and local redis server

Will install redis and rabbitmq servers, and assert the rabbitmq vhost and
user.

Example usage::

    include:
      - sensu.server

``client``
----------

Install sensu client and configure it to connect to the sensu server.

The client will be subscribe to checks on the 'all' channel, and to everything
in the ``roles`` grain.

Example usage::

    include:
      - sensu.client

Pillar variables
~~~~~~~~~~~~~~~~

The client will connect to the sensu server via rabbit MQ, controlled by the
following pillar values. It will default to connecting to monitoring.local on
the default rabbitmq port.

- sensu:rabbitmq:host

- sensu:rabbitmq:port

- sensu:rabbitmq:vhost

- sensu:rabbitmq:user

- sensu:rabbitmq:password

``sensu_check`` macro
---------------------

Macro to create a new check instance.

The macro has the following arguments:

name
  A for the check name. Must be unique on the enviornment

command
  The command to run for the check

handlers
  The type of the entries in this log file. Shows up as the type field in
  logstash.

  **Default:** [``default``]

interval
  How often (in seconds) to run the check

  **Default:** 60

subscribers
  Which clients should perform this check

  **Default:** [``all``]

occurrences
  Number of failure occurrences before the handler should take action

  **Default:** 1

playbook
  URL of a doc explaining how to deal with this alert. This will be used for
  hipchat notifier and possibly other handler types.

Example usage::

    include:
      - sensu.server

    {% from 'sensu/lib.sls' import sensu_check with context %}
    {# This check is included by default #}
    {{ sensu_check('check_swap', '/etc/sensu/plugins/system/check-swap-percentage.sh -w 5 -c 25') }}
    {# This check is better done as the sensu_check_proc macro though#}
    {{ sensu_check('check_swap', '/etc/sensu/community/plugins/processes/check-procs.rb -p salt-master -C 1', subscribers=['master'] }}



``sensu_check_graphite`` macro
------------------------------

Macro to perform a check against a graphite metric target

The macro accepts the following arguments in addition to those of the ```sensu_check`` macro`_:

name
  A for the check name. Must be unique on the box

metric_name
  The name of the metric/target to pull from graphite. This can be any standard graphite target
  and can therefore include any of the default graphite functions. If the test is host-specific
  the test can also refer to the hostpath by using the ``:::metric_prefix:::`` sensu variable.

desc
  The description of the check. This is used when generating alerts.

params
  The set of additional command line parameters for this check. This should
  either include the warning and critical levels, or the levels must be defined
  in the pillar - but not both.  For more details on the available options
  please consult the graphite check at
  ``./sensu/files/plugins/graphite-data.rb``.

``sensu_check_es`` macro
------------------------------

Macro to perform a check against an elastic search query

The macro accepts the following arguments in addition to those of the ```sensu_check`` macro`_:

query
  The ES query to run e.g. ``tags:rails AND @tags:exception``

  **Default:** *

out_tag
  A tag which will be inclued in the notification

  **Default:** es

output
  The text for the notification e.g. "Exception found in rails log!"

  **Default:** "Found results for: " + query 

Configuring thresholds
~~~~~~~~~~~~~~~~~~~~~~

This macro will look in the pillar under ``sensu:checks`` for a dictionary that
matches the check name (``free-root-disk`` in this example) and if that
contains ``warning`` or ``critical`` keys it will use those values and append
``-w`` and ``-c`` options to the params automatically.

Example usage::

    include:
      - sensu.server

    {% from 'sensu/lib.sls' import sensu_check_graphite with context %}
    {{ sensu_check_graphite("free-root-disk",
                        "metrics.:::metric_prefix:::.df.root.df_complex.free",
                        "--below -a 600",
                        "Root Disk Full") }}

With the following pillar (which is the default)::

    sensu:
      checks:
        free-root-disk:
            warning: 10737418240
            critical: 5368709120


``sensu_check_procs`` macro
---------------------------

Install a sensu check to make sure that the named process exists

The macro has the following arguments in addition to those of the
```sensu_check`` macro`_:

name
  The process name to check for.

  This will form a sensu check named 'process-' + ``name``

pattern
  If the pattern you want to check for is not 'url' safe then you can
  explicitly specify pattern to look for.

  For example if you want to check for ``mongod`` but not ``mongodump`` then
  you would specify a pattern of ``mongod$``

  **Default:** the same value as the name parameter

critical_under
  Raise an critical alert when there are fewer than this many processes matched

  **Default:** ``1``

critical_over
  Raise an critical alert when there are greater than this many processes
  matched

Example usage::

    include:
      - sensu.server

    {% from 'sensu/lib.sls' import sensu_check_procs with context %}
    {{ sensu_check_procs("salt-master", subscribers=["master"]) }}
    {{ sensu_check_procs("mongod", pattern="mongod$") }}



Notifications
=============

By default the sensu server will only generate notifications to STDOUT handler and therefore they will only be
visible in the dashboard and in sensu-server.log. To enable additional notification methods you need to 
enable them in the pillar. You can enable as many as you like of the additional notifications.

You can override the handler for the check in the pillar or the check definition. 

Example::

    sensu:
      checks:
        apparmor_check:
          handlers:
            - hipchat

The handler specified in the check definition will take precedence over the pillar. If you don't specify the handler the default is to use all the handlers enabled (as below)


Email
-----

Example::

    sensu:
      notify:
        email: 'alerts@mydomain.com'

HipChat
-------

You need to obtain an APIkey from Hipchat Admin. By default, if a roomname isn't specified it will sent Alerts
to the 'Alerts' room.

Or you can use your own api key if you bump the apiversion to v2 (it defaults to v1).

Example::

    sensu:
      notify:
        hipchat_apikey: c5wzTko0O59Xb6wlIKRstaQLbcsJJJFAANaEoD3
        hipchat_roomname: 'My Project Alerts'
        hipchat_apiversion: v1


Pagerduty
---------

To integrate with Pagerduty, you must first create a Service definition which is driven by an API key. 
Once you have this, you should add the generated API key to the default pillar.

Example::

    sensu:
      notify:
        pagerduty_apikey: 9e880a23f5ab1103bb7279896804e8a0


apparmor
========

This formula includes profiles for all the sensu components. Apparmor is by
default in complain mode which means it allows the action and logs. To make it
deny actions that the beaver profile doesn't cover set the following pillar::

    apparmor:
      profiles:
        sensu_api:
          enforce: ''
        sensu_client
          encorce: ''
        sensu_dashboard:
          encorce: ''
        sensu_server:
          encorce: ''


unix-socket-backlog
========

This check will find connections to a unix socket that are still connecting.

Example::

    {% from 'sensu/lib.sls' import sensu_check with context %}
    {{ sensu_check('unix-socket-backlog', '/etc/sensu/plugins/unix-socket-backlog.rb -s /var/run/unicorn.sock -w 1 -c 5', subscribers=['www']) }}
    
