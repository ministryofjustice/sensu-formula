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

``sensu_check_procs`` macro
---------------------------

Install a sensu check to make sure that the named process exists

The macro has the following arguments:

name
  The process name to check for.

  This will form a sensu check named 'process-' + ``name``
