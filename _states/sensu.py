# -*- coding: utf-8 -*-

# Import python libs
import os
import shutil
import difflib
import logging
import re
import fnmatch
import json
import pprint
import traceback

# Import third party libs
import yaml

# Import salt libs
import salt.utils
import salt.utils.templates
from salt.exceptions import CommandExecutionError
from salt._compat import string_types, integer_types

log = logging.getLogger(__name__)

COMMENT_REGEX = r'^([[:space:]]*){0}[[:space:]]?'

_ACCUMULATORS = {}
_ACCUMULATORS_DEPS = {}


def _error(ret, err_msg):
    ret['result'] = False
    ret['comment'] = err_msg
    return ret


def _test_owner(kwargs, user=None):
    '''
    Convert owner to user, since other config management tools use owner,
    no need to punish people coming from other systems.
    PLEASE DO NOT DOCUMENT THIS! WE USE USER, NOT OWNER!!!!
    '''
    if user:
        return user
    if 'owner' in kwargs:
        log.warning(
            'Use of argument owner found, "owner" is invalid, please '
            'use "user"'
        )
        return kwargs['owner']

    return user

def _check_user(user, group):
    '''
    Checks if the named user and group are present on the minion
    '''
    err = ''
    if user:
        uid = __salt__['file.user_to_uid'](user)
        if uid == '':
            err += 'User {0} is not available '.format(user)
    if group:
        gid = __salt__['file.group_to_gid'](group)
        if gid == '':
            err += 'Group {0} is not available'.format(group)
    return err


def _managed(name,
            source=None,
            source_hash='',
            user=None,
            group=None,
            mode=None,
            template=None,
            makedirs=False,
            dir_mode=None,
            context=None,
            replace=True,
            defaults=None,
            env=None,
            backup='',
            show_diff=True,
            create=True,
            contents=None,
            contents_pillar=None,
            **kwargs):
    '''
    Manage a given file, this function allows for a file to be downloaded from
    the salt master and potentially run through a templating system.

    name
        The location of the file to manage

    source
        The source file to download to the minion, this source file can be
        hosted on either the salt master server, or on an HTTP or FTP server.
        For files hosted on the salt file server, if the file is located on
        the master in the directory named spam, and is called eggs, the source
        string is salt://spam/eggs. If source is left blank or None
        (use ~ in YAML), the file will be created as an empty file and
        the content will not be managed

        If the file is hosted on a HTTP or FTP server then the source_hash
        argument is also required

    source_hash
        This can be one of the following:
            1. a source hash string
            2. the URI of a file that contains source hash strings

        The function accepts the first encountered long unbroken alphanumeric
        string of correct length as a valid hash, in order from most secure to
        least secure::

            Type    Length
            ======  ======
            sha512     128
            sha384      96
            sha256      64
            sha224      56
            sha1        40
            md5         32

        The file can contain several checksums for several files. Each line
        must contain both the file name and the hash.  If no file name is
        matched, the first hash encountered will be used, otherwise the most
        secure hash with the correct source file name will be used.

        Debian file type ``*.dsc`` is supported.

        Examples::

            /etc/rc.conf ef6e82e4006dee563d98ada2a2a80a27
            sha254c8525aee419eb649f0233be91c151178b30f0dff8ebbdcc8de71b1d5c8bcc06a  /etc/resolv.conf
            ead48423703509d37c4a90e6a0d53e143b6fc268

        Known issues:
            If the remote server URL has the hash file as an apparent
            sub-directory of the source file, the module will discover that it
            has already cached a directory where a file should be cached. For
            example:

            .. code-block:: yaml

                tomdroid-src-0.7.3.tar.gz:
                  file.managed:
                    - name: /tmp/tomdroid-src-0.7.3.tar.gz
                    - source: https://launchpad.net/tomdroid/beta/0.7.3/+download/tomdroid-src-0.7.3.tar.gz
                    - source_hash: https://launchpad.net/tomdroid/beta/0.7.3/+download/tomdroid-src-0.7.3.tar.gz/+md5


    user
        The user to own the file, this defaults to the user salt is running as
        on the minion

    group
        The group ownership set for the file, this defaults to the group salt
        is running as on the minion

    mode
        The permissions to set on this file, aka 644, 0775, 4664

    template
        If this setting is applied then the named templating engine will be
        used to render the downloaded file, currently jinja, mako, and wempy
        are supported

    makedirs
        If the file is located in a path without a parent directory, then
        the state will fail. If makedirs is set to True, then the parent
        directories will be created to facilitate the creation of the named
        file.

    dir_mode
        If directories are to be created, passing this option specifies the
        permissions for those directories. If this is not set, directories
        will be assigned permissions from the 'mode' argument.

    replace
        If this file should be replaced.  If false, this command will
        not overwrite file contents but will enforce permissions if the file
        exists already.  Default is True.

    context
        Overrides default context variables passed to the template.

    defaults
        Default context passed to the template.

    backup
        Overrides the default backup mode for this specific file.

    show_diff
        If set to False, the diff will not be shown.

    create
        Default is True, if create is set to False then the file will only be
        managed if the file already exists on the system.

    contents
        Default is None.  If specified, will use the given string as the
        contents of the file.  Should not be used in conjunction with a source
        file of any kind.  Ignores hashes and does not use a templating engine.

    contents_pillar
        .. versionadded:: 0.17.0

        Operates like ``contents``, but draws from a value stored in pillar,
        using the pillar path syntax used in :mod:`pillar.get
        <salt.modules.pillar.get>`. This is useful when the pillar value
        contains newlines, as referencing a pillar variable using a jinja/mako
        template can result in YAML formatting issues due to the newlines
        causing indentation mismatches.

        For example, the following could be used to deploy an SSH private key:

        .. code-block:: yaml

            /home/deployer/.ssh/id_rsa:
              file.managed:
                - user: deployer
                - group: deployer
                - mode: 600
                - contents_pillar: userdata:deployer:id_rsa

        This would populate ``/home/deployer/.ssh/id_rsa`` with the contents of
        ``pillar['userdata']['deployer']['id_rsa']``. An example of this pillar
        setup would be like so:

        .. code-block:: yaml:

            userdata:
              deployer:
                id_rsa: |
                  -----BEGIN RSA PRIVATE KEY-----
                  MIIEowIBAAKCAQEAoQiwO3JhBquPAalQF9qP1lLZNXVjYMIswrMe2HcWUVBgh+vY
                  U7sCwx/dH6+VvNwmCoqmNnP+8gTPKGl1vgAObJAnMT623dMXjVKwnEagZPRJIxDy
                  B/HaAre9euNiY3LvIzBTWRSeMfT+rWvIKVBpvwlgGrfgz70m0pqxu+UyFbAGLin+
                  GpxzZAMaFpZw4sSbIlRuissXZj/sHpQb8p9M5IeO4Z3rjkCP1cxI
                  -----END RSA PRIVATE KEY-----

        .. note::

            The private key above is shortened to keep the example brief, but
            shows how to do multiline string in YAML. The key is followed by a
            pipe character, and the mutli-line string is indented two more
            spaces.
    '''
    # Make sure that leading zeros stripped by YAML loader are added back
    mode = __salt__['config.manage_mode'](mode)

    user = _test_owner(kwargs, user=user)
    ret = {'changes': {},
           'comment': '',
           'name': name,
           'result': True}
    if not create:
        if not os.path.isfile(name):
            # Don't create a file that is not already present
            ret['comment'] = ('File {0} is not present and is not set for '
                              'creation').format(name)
            return ret
    u_check = _check_user(user, group)
    if u_check:
        # The specified user or group do not exist
        return _error(ret, u_check)
    if not os.path.isabs(name):
        return _error(
            ret, 'Specified file {0} is not an absolute path'.format(name))

    if isinstance(env, salt._compat.string_types):
        msg = (
            'Passing a salt environment should be done using \'saltenv\' not '
            '\'env\'. This warning will go away in Salt Boron and this '
            'will be the default and expected behaviour. Please update your '
            'state files.'
        )
        salt.utils.warn_until('Boron', msg)
        ret.setdefault('warnings', []).append(msg)
        # No need to set __env__ = env since that's done in the state machinery

    if os.path.isdir(name):
        ret['comment'] = 'Specified target {0} is a directory'.format(name)
        ret['result'] = False
        return ret

    if context is None:
        context = {}
    elif not isinstance(context, dict):
        return _error(
            ret, 'Context must be formed as a dict')

    if contents and contents_pillar:
        return _error(
            ret, 'Only one of contents and contents_pillar is permitted')

    # If contents_pillar was used, get the pillar data
    if contents_pillar:
        contents = __salt__['pillar.get'](contents_pillar)
        # Make sure file ends in newline
        if not contents.endswith('\n'):
            contents += '\n'

    if not replace and os.path.exists(name):
        # Check and set the permissions if necessary
        ret, _ = __salt__['file.check_perms'](name, ret, user, group, mode)
        if __opts__['test']:
            ret['comment'] = 'File {0} not updated'.format(name)
        elif not ret['changes'] and ret['result']:
            ret['comment'] = ('File {0} exists with proper permissions. '
                              'No changes made.'.format(name))
        return ret

    if name in _ACCUMULATORS:
        if not context:
            context = {}
        context['accumulator'] = _ACCUMULATORS[name]

    try:
        if __opts__['test']:
            ret['result'], ret['comment'] = __salt__['file.check_managed'](
                name,
                source,
                source_hash,
                user,
                group,
                mode,
                template,
                context,
                defaults,
                __env__,
                contents,
                **kwargs
            )
            return ret

        # If the source is a list then find which file exists
        source, source_hash = __salt__['file.source_list'](
            source,
            source_hash,
            __env__
        )
    except CommandExecutionError as exc:
        ret['result'] = False
        ret['comment'] = 'Unable to manage file: {0}'.format(exc)
        return ret

    # Gather the source file from the server
    try:
        sfn, source_sum, comment_ = __salt__['file.get_managed'](
            name,
            template,
            source,
            source_hash,
            user,
            group,
            mode,
            __env__,
            context,
            defaults,
            **kwargs
        )
    except Exception as exc:
        ret['changes'] = {}
        log.debug(traceback.format_exc())
        return _error(ret, 'Unable to manage file: {0}'.format(exc))

    if comment_ and contents is None:
        return _error(ret, comment_)
    else:
        try:
            return __salt__['file.manage_file'](
                name,
                sfn,
                ret,
                source,
                source_sum,
                user,
                group,
                mode,
                __env__,
                backup,
                makedirs,
                template,
                show_diff,
                contents,
                dir_mode)
        except Exception as exc:
            ret['changes'] = {}
            log.debug(traceback.format_exc())
            return _error(ret, 'Unable to manage file: {0}'.format(exc))


def _default_param(arglist, param_name, default, pillar={}):
    if param_name in arglist:
        return
    arglist[param_name] = default

def _sensucheck(name, **kwargs):
    _default_param(kwargs, 'command', 'mycommand')
    _default_param(kwargs, 'handlers', [ 'default' ])
    _default_param(kwargs, 'interval', 60)
    _default_param(kwargs, 'occurrences', 1)
    _default_param(kwargs, 'playbook', None)
    _default_param(kwargs, 'standalone', False)
    _default_param(kwargs, 'subscribers', [ 'all' ])
  
    kwargs['source'] = 'salt://sensu/templates/state_checks.json'
    kwargs['template'] = 'jinja'
    kwargs['checkname'] = name
    pathname = "/var/tmp/{}".format(name)
    return _managed(pathname, **kwargs)


def check(name, **kwargs):
    return _sensucheck(name, **kwargs)


def check_procs(name, critical_under=1, **kwargs):
    pattern = kwargs.get('pattern',name)
    kwargs['command'] = "/etc/sensu/community/plugins/processes/check-procs.rb -p {} -C {}".format(pattern, critical_under)
    
    if critical_over in kwargs:
        kwargs['command'] += " -c {}".format(critical_over)

    return _sensucheck(name, **kwargs)


def check_graphite(name, metric_name, params = '', desc, **kwargs):
    kwargs['command'] = "/etc/sensu/plugins/graphite-data.rb -t {} -n '{}' {}".format(metric_name, desc, params)
    
    return _sensucheck(name, **kwargs)


