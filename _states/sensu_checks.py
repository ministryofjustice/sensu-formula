#!/usr/bin/env python
from __future__ import absolute_import

# Import python libs
import difflib
import json
import logging
import os
import pprint
import shutil
import traceback
import yaml

# Import salt libs
import salt.utils
import salt.utils.templates
from salt.exceptions import CommandExecutionError
from salt.utils.serializers import yaml as yaml_serializer
from salt.utils.serializers import json as json_serializer
from salt.ext.six.moves import map
import salt.ext.six as six
from salt.ext.six import string_types, integer_types

log = logging.getLogger(__name__)

COMMENT_REGEX = r'^([[:space:]]*){0}[[:space:]]?'

_ACCUMULATORS = {}
_ACCUMULATORS_DEPS = {}

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

def _error(ret, err_msg):
    ret['result'] = False
    ret['comment'] = err_msg
    return ret

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
            contents_grains=None,
            contents_newline=True,
            follow_symlinks=True,
            check_cmd=None,
            **kwargs):
    '''
    Manage a given file, this function allows for a file to be downloaded from
    the salt master and potentially run through a templating system.
    name
        The location of the file to manage
    source
        The source file to download to the minion, this source file can be
        hosted on either the salt master server, or on an HTTP or FTP server.
        Both HTTPS and HTTP are supported as well as downloading directly
        from Amazon S3 compatible URLs with both pre-configured and automatic
        IAM credentials. (see s3.get state documentation)
        File retrieval from Openstack Swift object storage is supported via
        swift://container/object_path URLs, see swift.get documentation.
        For files hosted on the salt file server, if the file is located on
        the master in the directory named spam, and is called eggs, the source
        string is salt://spam/eggs. If source is left blank or None
        (use ~ in YAML), the file will be created as an empty file and
        the content will not be managed
        If the file is hosted on a HTTP or FTP server then the source_hash
        argument is also required
        A list of sources can also be passed in to provide a default source and
        a set of fallbacks. The first source in the list that is found to exist
        will be used and subsequent entries in the list will be ignored.
        .. code-block:: yaml
            file_override_example:
              file.managed:
                - source:
                  - salt://file_that_does_not_exist
                  - salt://file_that_exists
    source_hash
        This can be one of the following:
            1. a source hash string
            2. the URI of a file that contains source hash strings
        The function accepts the first encountered long unbroken alphanumeric
        string of correct length as a valid hash, in order from most secure to
        least secure:
        .. code-block:: text
            Type    Length
            ======  ======
            sha512     128
            sha384      96
            sha256      64
            sha224      56
            sha1        40
            md5         32
        **Using a Source Hash File**
            The file can contain several checksums for several files. Each line
            must contain both the file name and the hash.  If no file name is
            matched, the first hash encountered will be used, otherwise the most
            secure hash with the correct source file name will be used.
            When using a source hash file the source_hash argument needs to be a
            url, the standard download urls are supported, ftp, http, salt etc:
            Example:
            .. code-block:: yaml
                tomdroid-src-0.7.3.tar.gz:
                  file.managed:
                    - name: /tmp/tomdroid-src-0.7.3.tar.gz
                    - source: https://launchpad.net/tomdroid/beta/0.7.3/+download/tomdroid-src-0.7.3.tar.gz
                    - source_hash: https://launchpad.net/tomdroid/beta/0.7.3/+download/tomdroid-src-0.7.3.hash
            The following is an example of the supported source_hash format:
            .. code-block:: text
                /etc/rc.conf ef6e82e4006dee563d98ada2a2a80a27
                sha254c8525aee419eb649f0233be91c151178b30f0dff8ebbdcc8de71b1d5c8bcc06a  /etc/resolv.conf
                ead48423703509d37c4a90e6a0d53e143b6fc268
            Debian file type ``*.dsc`` files are also supported.
        **Inserting the Source Hash in the sls Data**
            Examples:
            .. code-block:: yaml
                tomdroid-src-0.7.3.tar.gz:
                  file.managed:
                    - name: /tmp/tomdroid-src-0.7.3.tar.gz
                    - source: https://launchpad.net/tomdroid/beta/0.7.3/+download/tomdroid-src-0.7.3.tar.gz
                    - source_hash: md5=79eef25f9b0b2c642c62b7f737d4f53f
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
        is running as on the minion On Windows, this is ignored
    mode
        The permissions to set on this file, aka 644, 0775, 4664. Not supported
        on Windows
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
        .. code-block:: yaml
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
            pipe character, and the mutliline string is indented two more
            spaces.
    contents_grains
        .. versionadded:: 2014.7.0
        Same as contents_pillar, but with grains
    contents_newline
        .. versionadded:: 2014.7.0
        When using contents, contents_pillar, or contents_grains, this option
        ensures the file will have a newline at the end.
        When loading some data this newline is better left off. Setting
        contents_newline to False will omit this final newline.
    follow_symlinks : True
        .. versionadded:: 2014.7.0
        If the desired path is a symlink follow it and make changes to the
        file to which the symlink points.
    check_cmd
        .. versionadded:: 2014.7.0
        The specified command will be run with the managed file as an argument.
        If the command exits with a nonzero exit code, the command will not be
        run.
    '''
    name = os.path.expanduser(name)
    # contents must be a string
    if contents:
        contents = str(contents)

    # Make sure that leading zeros stripped by YAML loader are added back
    mode = __salt__['config.manage_mode'](mode)

    # If no source is specified, set replace to False, as there is nothing
    # to replace the file with.
    src_defined = source or contents or contents_pillar or contents_grains
    if not src_defined and replace:
        replace = False
        log.warning(
            'Neither \'source\' nor \'contents\' nor \'contents_pillar\' nor \'contents_grains\' '
            'was defined, yet \'replace\' was set to \'True\'. As there is '
            'no source to replace the file with, \'replace\' has been set '
            'to \'False\' to avoid reading the file unnecessarily'
        )

    ret = {'changes': {},
           'comment': '',
           'name': name,
           'result': True}
    if not name:
        return _error(ret, 'Must provide name to file.exists')
    user = _test_owner(kwargs, user=user)
    if salt.utils.is_windows():
        if group is not None:
            log.warning(
                'The group argument for {0} has been ignored as this '
                'is a Windows system.'.format(name)
            )
        group = user
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

    if isinstance(env, string_types):
        msg = (
            'Passing a salt environment should be done using \'saltenv\' not '
            '\'env\'. This warning will go away in Salt Boron and this '
            'will be the default and expected behavior. Please update your '
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
    if defaults and not isinstance(defaults, dict):
        return _error(
            ret, 'Defaults must be formed as a dict')

    if len([_f for _f in [contents, contents_pillar, contents_grains] if _f]) > 1:
        return _error(
            ret, 'Only one of contents, contents_pillar, and contents_grains is permitted')

    # If contents_pillar was used, get the pillar data
    if contents_pillar:
        contents = __salt__['pillar.get'](contents_pillar)

    if contents_grains:
        contents = __salt__['grains.get'](contents_grains)

    if contents_newline:
        # Make sure file ends in newline
        if contents and not contents.endswith('\n'):
            contents += '\n'

    if not replace and os.path.exists(name):
        # Check and set the permissions if necessary
        ret, _ = __salt__['file.check_perms'](name, ret, user, group, mode, follow_symlinks)
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
            ret['result'] = None
            ret['changes'] = __salt__['file.check_managed_changes'](
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

            if ret['changes']:
                ret['comment'] = 'The file {0} is set to be changed'.format(name)
            else:
                ret['comment'] = 'The file {0} is in the correct state'.format(name)

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

    if check_cmd:
        tmp_filename = salt.utils.mkstemp()

        # if exists copy existing file to tmp to compare
        if __salt__['file.file_exists'](name):
            try:
                __salt__['file.copy'](name, tmp_filename)
            except Exception as exc:
                return _error(ret, 'Unable to copy file {0} to {1}: {2}'.format(name, tmp_filename, exc))

        try:
            ret = __salt__['file.manage_file'](
                tmp_filename,
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
                dir_mode,
                follow_symlinks)
        except Exception as exc:
            ret['changes'] = {}
            log.debug(traceback.format_exc())
            return _error(ret, 'Unable to check_cmd file: {0}'.format(exc))

        # file being updated to verify using check_cmd
        if ret['changes']:
            # Reset ret
            ret = {'changes': {},
                   'comment': '',
                   'name': name,
                   'result': True}

            check_cmd_opts = {}
            if 'shell' in __grains__:
                check_cmd_opts['shell'] = __grains__['shell']

            cret = mod_run_check_cmd(check_cmd, tmp_filename, **check_cmd_opts)
            if isinstance(cret, dict):
                ret.update(cret)
                return ret
        else:
            ret = {'changes': {},
                   'comment': '',
                   'name': name,
                   'result': True}

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
                dir_mode,
                follow_symlinks)
        except Exception as exc:
            ret['changes'] = {}
            log.debug(traceback.format_exc())
            return _error(ret, 'Unable to manage file: {0}'.format(exc))

def check(name, command, handlers=['default'], interval=60, subscribers=['all'], standalone=False, occurrences=1, playbook=False):

    check = { 'checks':
                { name: locals() }
            }

    check_json = json.dumps(check)
    ret = _managed('/etc/sensu/conf.d/checks/{0}.json'.format(name),
                   user='sensu',
                   group='sensu',
                   mode=600,
                   replace=True,
                   contents=check_json)
    return ret
