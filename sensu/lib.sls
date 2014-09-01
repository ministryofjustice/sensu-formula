{#
include:
  - sensu.common


sensu_check:
generic check executor

sensu_check_procs:
execute check is process exists

#}

{% from "sensu/map.jinja" import sensu with context %}

{% macro sensu_check(name, command, handlers=['default'], interval=60, subscribers=['all'], standalone=False, occurrences=1) %}

/etc/sensu/conf.d/checks/{{name}}.json:
  file.managed:
    - source: salt://sensu/templates/checks.json
    - template: jinja
    - mode: 600
    - owner: sensu
    - group: sensu
    - context:
        name: {{name}}
        command: {{command}}
        handlers: {{handlers}}
        interval: {{interval}}
        standalone: {{standalone}}
        subscribers: {{subscribers}}
        occurrences: {{occurrences}}
    - require:
      - file: sensu-confd-checks-dir
    - require_in:
      - file: sensu-confd-checks-clean
    - watch_in:
        - service: sensu-client

{% endmacro %}

{% macro sensu_check_procs(name, critical_under=1) %}
{% set check_cmd =  "/etc/sensu/community/plugins/processes/check-procs.rb -p "+name+" -C " + critical_under|string %}
{% if 'critical_over' in kwargs %}
  {% set check_cmd = check_cmd + " -c " + kwargs.critical_over|string %}
{% endif %}
{% set standalone = kwargs.standalone|default(False) %}
{{ sensu_check(name="process-"+name, command=check_cmd, standalone=standalone) }}
{% endmacro %}

{# TODO: This would be *much* nicer as a state/module rather than a macro. Work
   out how we write and ship one #}
{% macro sensu_check_graphite(name, metric_name, params, desc, occurrences=1) %}
{% set p_data = sensu.checks.get(name, {}) %}
{% if "warning" in p_data %}
  {% set params = params + " -w " ~ p_data.warning %}
{% endif %}
{% if "critical" in p_data %}
  {% set params = params + " -c " ~ p_data.critical %}
{% endif %}
{% set check_cmd = "/etc/sensu/plugins/graphite-data.rb -s " + sensu.graphite.host + ":" ~ sensu.graphite.port ~ " -t "+metric_name+" -n '"+desc+"' " + params %}
{% set standalone = kwargs.standalone|default(False) %}
{{ sensu_check(name="graphite-"+name, command=check_cmd, standalone=standalone, occurrences=occurrences) }}
{% endmacro %}
