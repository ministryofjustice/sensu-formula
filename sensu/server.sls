{% from "sensu/map.jinja" import sensu with context %}
{% from "sensu/lib.sls" import sensu_check_procs with context %}
{% from "sensu/lib.sls" import sensu_check with context %}
{% from 'logstash/lib.sls' import logship with context %}

include:
  - firewall
  - bootstrap
  - nginx
  - redis
  - logstash.client
  - rabbitmq
  - apparmor
  - repos
  - .client
  - .common
  - .deps
  - .checks
# for git


/etc/sensu/conf.d/redis.json:
  file.managed:
    - source: salt://sensu/templates/redis.json
    - template: 'jinja'

{%- if sensu.notify.email %}
sensu-mailutils:
  pkg.installed:
    - name: mailutils
    - watch_in:
      - service: sensu-server
{% endif %}

{%- if sensu.notify.pagerduty_apikey %}
sensu_redphone:
  cmd.run:
    - name: /opt/sensu/embedded/bin/gem install redphone
    - unless: /opt/sensu/embedded/bin/gem list -i redphone
    - require:
      - pkg: sensu
    - watch_in:
      - service: sensu-server
{% endif %}

{%- if sensu.notify.hipchat_apikey %}
sensu_hipchat:
  cmd.run:
    - name: /opt/sensu/embedded/bin/gem install hipchat
    - unless: /opt/sensu/embedded/bin/gem list -i hipchat
    - require:
      - pkg: sensu
    - watch_in:
      - service: sensu-server
{% endif %}

/etc/sensu/conf.d/api.json:
  file.managed:
    - source: salt://sensu/templates/api.json
    - template: 'jinja'

/etc/sensu/conf.d/handlers.json:
  file.managed:
    - source: salt://sensu/templates/handlers.json
    - template: 'jinja'


sensu-server:
  service.running:
    - enable: True
    - watch:
      - file: /etc/default/sensu
      - file: /etc/sensu/conf.d/redis.json
      - file: /etc/sensu/conf.d/rabbitmq.json
      - file: /etc/sensu/conf.d/handlers.json
      - file: /etc/sensu/conf.d/checks/*

/etc/apparmor.d/opt.sensu.embedded.bin.sensu-server:
  file.managed:
    - source: salt://sensu/templates/server_apparmor_profile
    - template: jinja
    - watch_in:
       - service: sensu-server


sensu-api:
  service.running:
    - enable: True
    - watch:
      - file: /etc/default/sensu
      - file: /etc/sensu/conf.d/api.json
      - file: /etc/sensu/conf.d/redis.json

/etc/apparmor.d/opt.sensu.embedded.bin.sensu-api:
  file.managed:
    - source: salt://sensu/templates/api_apparmor_profile
    - template: jinja
    - watch_in:
       - service: sensu-api

sensu_rabbitmq_user:
  rabbitmq_user.present:
    - name: {{ sensu.rabbitmq.user }}
    - password: {{ sensu.rabbitmq.password }}
    - require:
      - pkg: rabbitmq-server
      - service: rabbitmq-server
    - require_in:
      - service: sensu-api
      - service: sensu-server

#perms are not working so we fall back to owner
sensu_rabbitmq_vhost:
  rabbitmq_vhost.present:
    - name: {{ sensu.rabbitmq.vhost }}
    - owner: {{ sensu.rabbitmq.user }}
    - require:
      - rabbitmq_user: sensu_rabbitmq_user
    - require_in:
      - service: sensu-api
      - service: sensu-server

/etc/init/uchiwa.conf:
  file.managed:
    - source: salt://sensu/files/uchiwa.conf
    - requires:
      - file: /etc/init.d/uchiwa

/etc/init.d/uchiwa:
  file:
    - absent

uchiwa:
  user.present:
    - groups: [sensu]
    - require:
      - pkg: uchiwa
  pkg:
    - installed
    - version: {{ sensu.uchiwa.version }}
  service.running:
    - require:
      - file: /etc/sensu/uchiwa.json
    - watch:
      - file: /etc/init/uchiwa.conf
      - file: /etc/sensu/uchiwa.json
  file.managed:
    - name: /etc/sensu/uchiwa.json
    - user: uchiwa
    - group: uchiwa
    - template: jinja
    - source: salt://sensu/templates/uchiwa.json
    - require:
      - file: /etc/sensu
      - pkg: uchiwa

/etc/apparmor.d/opt.uchiwa.embedded.bin.node:
  file.managed:
    - source: salt://sensu/templates/uchiwa_apparmor_profile
    - template: jinja
    - watch_in:
       - service: uchiwa


{{ logship('sensu-server.log',  '/var/log/sensu/sensu-server.log', 'sensu', ['sensu', 'sensu-server', 'log'],  'rawjson') }}
{{ logship('sensu-api.log',  '/var/log/sensu/sensu-api.log', 'sensu', ['sensu', 'sensu-api', 'log'],  'rawjson') }}
{{ logship('uchiwa.log',  '/var/log/upstart/uchiwa.log', 'sensu', ['sensu', 'sensu-dashboard', 'uchiwa', 'log'],  'rawjson') }}


/etc/nginx/conf.d/sensu.conf:
  file.managed:
    - source: salt://nginx/templates/vhost-proxy.conf
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - context:
        appslug: sensu
        server_name: sensu.*
        proxy_to: localhost:3000
        is_default: False
    - watch_in:
      - service: nginx


{{ logship('sensu-access',  '/var/log/nginx/sensu.access.json', 'nginx', ['nginx', 'sensu', 'access'],  'rawjson') }}
{{ logship('sensu-error',  '/var/log/nginx/sensu.error.json', 'nginx', ['nginx', 'sensu', 'error'],  'json') }}
