{% from "sensu/map.jinja" import sensu with context %}
{% from "logstash/lib.sls" import logship with context %}

include:
  - apparmor
  - logstash.client
  - .common

/etc/sensu/conf.d/rabbitmq.json:
  file.managed:
    - source: salt://sensu/templates/rabbitmq.json
    - template: jinja
    - mode: 644


/etc/sensu/conf.d/client.json:
  file.managed:
    - source: salt://sensu/templates/client.json
    - template: jinja
    - mode: 644


# Sensu Community Plugins
https://github.com/sensu/sensu-community-plugins.git:
  git.latest:
    - target: /etc/sensu/community
    - rev: {{ sensu.community_plugins_rev }}
    - require:
      - pkg: sensu_deps

sensu_plugins_remove_symlink:
  cmd.run:
    # We used to have the community plugins installed in /etc/sensu/community
    # and symlinked to /etc/sensu/plugins. We don't want that anymore but need
    # to remove the symlink first
    - name: rm /etc/sensu/plugins
    - onlyif: '[ -L /etc/sensu/plugins ]'

# Locally created plugins
/etc/sensu/plugins:
  file.recurse:
    - source: salt://sensu/files/plugins
    - include_empty: True
    - clean: True
    - user: sensu
    - group: sensu
    - file_mode: 700
    - dir_mode: 700
    - require:
      - cmd: sensu_plugins_remove_symlink
      - cmd: rest-client
      - cmd: raindrops

raindrops:
  cmd.run:
    - name: /opt/sensu/embedded/bin/gem install raindrops --no-rdoc --no-ri
    - unless: /opt/sensu/embedded/bin/gem which raindrops >/dev/null 2>/dev/null

rest-client:
  cmd.run:
    - name: /opt/sensu/embedded/bin/gem install rest-client --no-rdoc --no-ri
    - unless: /opt/sensu/embedded/bin/gem which rest-client >/dev/null 2>/dev/null

sensu-client:
  service.running:
    - enable: True
    - watch:
      - file: /etc/default/sensu
      - file: /etc/sensu/conf.d/*
    - order: last

/etc/apparmor.d/opt.sensu.embedded.bin.sensu-client:
  file.managed:
    - source: salt://sensu/templates/client_apparmor_profile
    - template: jinja
    - watch_in:
       - service: sensu-client

# order last as a hask workaround for sensu: Client exits on failure to connect #680
# https://github.com/sensu/sensu/issues/680


{{ logship('sensu-client.log',  '/var/log/sensu/sensu-client.log', 'sensu', ['sensu', 'sensu-client', 'log'],  'rawjson') }}
