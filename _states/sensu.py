import json

import salt.exceptions
import salt.states.file

def __virtual__():
    '''
    Only run on sensu servers 
    '''
    return 'sensu'

def check(name, command, handlers=None, interval=60, subscribers=['all'], standalone=False, occurrences=1, playbook=False):

    sensu_pillar = __salt__['pillar.get']('sensu',{})
    check_pillar = sensu_pillar['checks'].get(name, {})

    if handlers:
        handlers = handlers
    elif handlers in check_pillar:
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

    data = {'state': 'file',
            'fun': 'managed',
            'name': '/etc/sensu/conf.d/checks/{0}.json'.format(name),
            'template': 'jinja',
            'mode': 600,
            'owner': 'sensu',
            'group': 'sensu',
            'contents': json.dumps(check)}
            
    return __salt__['state.low'](data)

#def graphite_check(
