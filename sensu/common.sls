include:
  - .deps

sensu:
  pkg.installed


/etc/default/sensu:
  file.managed:
    - source: salt://sensu/files/default_sensu
    - require:
      - pkg: sensu


/etc/sensu:
  file.directory:
    - user: sensu
    - group: sensu
    - mode: 700
    - require:
      - pkg: sensu

/etc/sensu/conf.d/checks:
  file.directory:
    - clean: True
    - require:
      - pkg: sensu

