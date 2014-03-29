{#
include:
  - sensu.common


sensu_check:
generic check executor

sensu_check_procs:
execute check is process exists

#}


{% macro sensu_check(name, command, handlers=['default'], interval=60, subscribers=['all'], standalone=False) %}

/etc/sensu/conf.d/checks/{{name}}.json:
  file:
    - managed
    - source: salt://sensu/templates/checks.json
    - template: jinja
    - context:
        name: {{name}}
        command: {{command}}
        handlers: {{handlers}}
        interval: {{interval}}
        standalone: {{standalone}}
        subscribers: {{subscribers}}
    - require:
      - file: /etc/sensu/conf.d/checks
    - watch_in:
        - service: sensu-client

{% endmacro %}

{% macro sensu_check_procs(name, critical_under=1) %}
{% set check_cmd =  "/etc/sensu/plugins/processes/check-procs.rb -p "+name+" -C " + critical_under|string %}
{% if 'critical_over' in kwargs %}
  {% set check_cmd = check_cmd + " -c " + kwargs.critical_over|string %}
{% endif %}
{% set standalone = kwargs.standalone|default(False) %}
{{ sensu_check(name="process-"+name, command=check_cmd, standalone=standalone) }}
{% endmacro %}
