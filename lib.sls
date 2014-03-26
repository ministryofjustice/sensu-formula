{#
include:
  - sensu.common


sensu_check:
generic check executor

sensu_check_procs:
execute check is process exists

#}


{% macro sensu_check(name, command, handlers=['default'], interval=60, subscribers=['all']) %}

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
        subscribers: {{subscribers}}
    - require:
      - file: /etc/sensu/conf.d/checks
    - watch_in:
        - service: sensu-client

{% endmacro %}

{% macro sensu_check_procs(name) %}
{{ sensu_check("process-"+name, "/etc/sensu/plugins/processes/check-procs.rb -p "+name+" -C 1") }}
{% endmacro %}
