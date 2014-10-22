include:
  - .deps

# last sensu version with old dashboard (why can't ubuntu support semver)
# temporally pinning
sensu:
  pkg.installed:
    - version: 0.13.1-1

{% if 'sensu' not in salt['grains.get']('admins_extra_groups', []) %}
sensu_admin_group_grain:
  cmd.run:
    - name: salt-call grains.append admins_extra_groups sensu
{% endif %}

/etc/default/sensu:
  file.managed:
    - source: salt://sensu/files/default_sensu
    - require:
      - pkg: sensu


/etc/sensu:
  file.directory:
    - user: root
    - group: sensu
    - mode: 2750
    - require:
      - pkg: sensu


# The logic below is pretty warped but it seems like the only way
# for salt to treat a managed directory as idempotent to ensure
# that changes in state are not incorrectly generated.

sensu-confd-checks-clean:
  file.directory:
    - name: /etc/sensu/conf.d/checks
    - user: root
    - group: sensu
    - mode: 2750
    - clean: True
    - require:
      - pkg: sensu
      - file: sensu-confd-checks-dir

sensu-confd-checks-dir:
  file.directory:
    - name: /etc/sensu/conf.d/checks
    - user: root
    - group: sensu
    - mode: 2750
    - require:
      - pkg: sensu
