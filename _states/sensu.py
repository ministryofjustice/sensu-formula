import json

import salt.exceptions
from salt.states.file import managed

def __virtual__():
    '''
    Only run on sensu servers 
    '''
    if __salt__['file.directory_exists']('/etc/sensu/conf.d'):
        return 'sensu'
    else:
        return False

def check(name, command, handlers=None, interval=60, subscribers=['all'], standalone=False, occurrences=1, playbook=False):

    sensu_pillar = __salt__['pillar.get']('sensu',{})
    check_pillar = sensu_pillar['checks'].get(name, {})

    if handlers:
        # then leave them alone
    elif handlers in check_pillar
        handlers = check_pillar['handlers']
    else:
        handlers = ['default']

    check = {
      "checks": {
        name : {
          "handlers": handlers,
          "command": command,
          "interval": interval,
          "occurrences": occurrences,
          "subscribers": subscribers,
          "playbook": playbook 
        }
      }
    }


    return managed('/etc/sensu/conf.d/checks/{0}.json'.format(name), source='salt://sensu/templates/checks.json', template='jinja', mode=600, owner='sensu', group='sensu', contents=json.dumps(check))

#def graphite_check(
