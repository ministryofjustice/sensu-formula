=======
sensu
=======

Install and configure sensu and some simple common checks (disk, memory etc.)

.. note::

    See the full `Salt Formulas installation and usage instructions
    <http://docs.saltstack.com/topics/conventions/formulas.html>`_.


Dependencies
============

.. note::

   This formula has a dependency on the following salt formulas:

   `logstash <https://github.com/ministryofjustice/logstash-formula>`_

   `redis <https://github.com/ministryofjustice/redis-formula>`_

   `rabbitmq <https://github.com/ministryofjustice/rabbitmq-formula>`_

   `nginx <https://github.com/ministryofjustice/nginx-formula>`_


Available states
================

.. contents::
    :local:

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

Example usage::

    include:
      - sensu.client

    {% from 'sensu.sls' import sensu_check with context %}
    {# This check is included by default #}
    {{ sensu_check('check_swap', '/etc/sensu/plugins/system/check-swap-percentage.sh -w 5 -c 25') }}



``sensu_check_graphite`` macro
------------------------------

Macro to perform a check against a graphite metric target

The macro has the following arguments:

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


Configuring thresholds
~~~~~~~~~~~~~~~~~~~~~~

This macro will look in the pillar under ``sensu:checks`` for a dictionary that
matches the check name (``free-root-disk`` in this example) and if that
contains ``warning`` or ``critical`` keys it will use those values and append
``-w`` and ``-c`` options to the params automatically.

Example usage::

    include:
      - sensu.client

    {% from 'sensu.sls' import sensu_check_graphite with context %}
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

The macro has the following arguments:

name
  The process name to check for.

  This will form a sensu check named 'process-' + ``name``


Notifications
=============

By default the sensu server will only generate notifications to STDOUT and therefore they will only be
visible in the dashboard and in sensu-server.log. To enable additional notification methods you need to 
enable them in the pillar. You can enable as many as you like of the additional notifications.

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

Example::

    sensu:
      notify:
        hipchat_apikey: c5wzTko0O59Xb6wlIKRstaQLbcsJJJFAANaEoD3
        hipchat_roomname: 'My Project Alerts'


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
