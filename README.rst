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
-----------

Macro to ship a given log file with beaver to central logstash server.

The macro has the following arguments:

name
  A for the check name. Must be unique on the box

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

  **Default:** [``all``]

Example usage::

    include:
      - sensu.client

    {% from 'sensu.sls' import sensu_check with context %}
    {# This check is included by default #}
    {{ sensu_check('check_swap', '/etc/sensu/plugins/system/check-swap-percentage.sh -w 5 -c 25') }}



``sensu_check_graphite`` macro
-----------

sensu_check_graphite(name, metric_name, params, desc
Macro to perform a check against a graphite target

The macro has the following arguments:

name
  A for the check name. Must be unique on the box

metric_name
  The name of the metric/target to pull from graphite. This can be any standard graphite target
  and can therefore include any of the default graphite functions. If the test is host-specific
  the test can also refer to the hostpath by using the :::metric_prefix::: sensu variable.

params
  The set of additional parameters for this check, which should include the critical and warning
  thresholds. For more details on the available options please consult the graphite check at
  ``./sensu/files/plugins/graphite-data.rb``.


desc
  The description of the check. This is used when generating alerts.


Example usage::

    include:
      - sensu.client

    {% from 'sensu.sls' import sensu_check_graphite with context %}
    {{ sensu_check_graphite("free-root-disk",
                        "metrics.:::metric_prefix:::.df.root.df_complex.free",
                        "--below -w 10737418240 -c 5368709120 -a 600",
                        "Root Disk Full") }}


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
~~~~~

Example::

    sensu:
      notify:
        email: 'alerts@mydomain.com'

HipChat
~~~~~~~

You need to obtain an APIkey from Hipchat Admin. By default, if a roomname isn't specified it will sent Alerts
to the 'Alerts' room.

Example::

    sensu:
      notify:
        hipchat_apikey: c5wzTko0O59Xb6wlIKRstaQLbcsJJJFAANaEoD3
        hipchat_room: 'My Project Alerts'


Pagerduty
~~~~~~~~~

To integrate with Pagerduty, you must first create a Service definition which is driven by an API key. 
Once you have this, you should add the generated API key to the default pillar.

Example::

    sensu:
      notify:
        pagerduty_apikey: 9e880a23f5ab1103bb7279896804e8a0


