{% from "sensu/map.jinja" import sensu with context %}
{% from "logstash/lib.sls" import logship with context %}
{% from "sensu/lib.sls" import sensu_check,sensu_check_graphite,sensu_check_procs with context %}

{% set check_definitions = sensu.check_definitions %}
{% for name, check in check_definitions.iteritems() %}
{%   if check['type'] == 'graphite' %}
{{ sensu_check_graphite(
               name,
               check['target'],
               check['params']|default(''),
               check['description']|default(''),
               subscribers=check['subscribers']|default(['all']),
               handlers=check['handlers']|default(['default']),
               interval=check['interval']|default(60),
               occurrences=check['occurrences']|default(1),
               standalone=check['standalone']|default(False),
               playbook=check['playbook']|default(False)
               )
               }}
{%   elif check['type'] == 'procs' %}
{{ sensu_check_procs(
               name,
               pattern=check['pattern']|default(name),
               critical_under=check['critical_under']|default(1),
               subscribers=check['subscribers']|default(['all']),
               handlers=check['handlers']|default(['default']),
               interval=check['interval']|default(60),
               occurrences=check['occurrences']|default(1),
               standalone=check['standalone']|default(False),
               playbook=check['playbook']|default(False)
               )
               }}
{%   elif check['type'] == 'basic' %}
{{ sensu_check(
               name,
               check['command'],
               subscribers=check['subscribers']|default(['all']),
               handlers=check['handlers']|default(['default']),
               interval=check['interval']|default(60),
               occurrences=check['occurrences']|default(1),
               standalone=check['standalone']|default(False),
               playbook=check['playbook']|default(False)
               )
               }}
{%   endif %}
{% endfor %}
