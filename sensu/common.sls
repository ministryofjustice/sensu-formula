include:
  - .deps

# last sensu version with old dashboard (why can't ubuntu support semver)
# temporally pinning
sensu:
  pkg.installed:
    - version: 0.12.6-5


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


# The logic below is pretty warped but it seems like the only way
# for salt to treat a managed directory as idempotent to ensure
# that changes in state are not incorrectly generated.

sensu-confd-checks-clean:
  file.directory:
    - name: /etc/sensu/conf.d/checks
    - clean: True
    - require:
      - pkg: sensu
      - file: sensu-confd-checks-dir

sensu-confd-checks-dir:
  file.directory:
    - name: /etc/sensu/conf.d/checks
    - require:
      - pkg: sensu
