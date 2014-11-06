#
# This allows checks to be taken from the pillar. Just include 
# sensu.pillar in your top.sls
#
# TODO: Check the require/watch logic - hasn't been checked!!!
# This needs to be added in the macro to ensure ordering
{% for check in pillar.get('sensu_checks', []) %}

{{ check.name }}:
  sensu.check_by_name:
    - pillar: {{ check|yaml }}
    - require:
      - file: /etc/sensu/conf.d/checks
    - watch_in:
      - service: sensu-server

{% endfor %}

