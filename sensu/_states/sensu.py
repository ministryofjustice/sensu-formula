# -*- coding: utf-8 -*-
'''
Operations on regular files, special files, directories, and symlinks
=====================================================================

Salt States can aggressively manipulate files on a system. There are a number
of ways in which files can be managed.

Regular files can be enforced with the ``managed`` function. This function
downloads files from the salt master and places them on the target system.
The downloaded files can be rendered as a jinja, mako, or wempy template,
adding a dynamic component to file management. An example of ``file.managed``
which makes use of the jinja templating system would look like this:

.. code-block:: yaml

    /etc/http/conf/http.conf:
      file.managed:
        - source: salt://apache/http.conf
        - user: root
        - group: root
        - mode: 644
        - template: jinja
        - defaults:
            custom_var: "default value"
            other_var: 123
    {% if grains['os'] == 'Ubuntu' %}
        - context:
            custom_var: "override"
    {% endif %}

.. note::

    When using both the ``defaults`` and ``context`` arguments, note the extra
    indentation (four spaces instead of the normal two). This is due to an
    idiosyncrasy of how PyYAML loads nested dictionaries, and is explained in
    greater detail :ref:`here <nested-dict-indentation>`.

If using a template, any user-defined template variables in the file defined in
``source`` must be passed in using the ``defaults`` and/or ``context``
arguments. The general best practice is to place default values in
``defaults``, with conditional overrides going into ``context``, as seen above.

The ``source`` parameter can be specified as a list. If this is done, then the
first file to be matched will be the one that is used. This allows you to have
a default file on which to fall back if the desired file does not exist on the
salt fileserver. Here's an example:

.. code-block:: yaml

    /etc/foo.conf:
      file.managed:
        - source:
          - salt://foo.conf.{{ grains['fqdn'] }}
          - salt://foo.conf.fallback
        - user: foo
        - group: users
        - mode: 644
        - backup: minion

.. note::

    Salt supports backing up managed files via the backup option. For more
    details on this functionality please review the
    :doc:`backup_mode documentation </ref/states/backup_mode>`.

The ``source`` parameter can also specify a file in another Salt environment.
In this example ``foo.conf`` in the ``dev`` environment will be used instead.

.. code-block:: yaml

    /etc/foo.conf:
      file.managed:
        - source:
          - salt://foo.conf?saltenv=dev
        - user: foo
        - group: users
        - mode: '0644'

.. warning::

        When using a mode that includes a leading zero you must wrap the
        value in single quotes. If the value is not wrapped in quotes it
        will be read by YAML as an integer and evaluated as an octal.

Special files can be managed via the ``mknod`` function. This function will
create and enforce the permissions on a special file. The function supports the
creation of character devices, block devices, and fifo pipes. The function will
create the directory structure up to the special file if it is needed on the
minion. The function will not overwrite or operate on (change major/minor
numbers) existing special files with the exception of user, group, and
permissions. In most cases the creation of some special files require root
permisisons on the minion. This would require that the minion to be run as the
root user. Here is an example of a character device:

.. code-block:: yaml

    /var/named/chroot/dev/random:
      file.mknod:
        - ntype: c
        - major: 1
        - minor: 8
        - user: named
        - group: named
        - mode: 660

Here is an example of a block device:

.. code-block:: yaml

    /var/named/chroot/dev/loop0:
      file.mknod:
        - ntype: b
        - major: 7
        - minor: 0
        - user: named
        - group: named
        - mode: 660

Here is an example of a fifo pipe:

.. code-block:: yaml

    /var/named/chroot/var/log/logfifo:
      file.mknod:
        - ntype: p
        - user: named
        - group: named
        - mode: 660

Directories can be managed via the ``directory`` function. This function can
create and enforce the permissions on a directory. A directory statement will
look like this:

.. code-block:: yaml

    /srv/stuff/substuf:
      file.directory:
        - user: fred
        - group: users
        - mode: 755
        - makedirs: True

If you need to enforce user and/or group ownership or permissions recursively
on the directory's contents, you can do so by adding a ``recurse`` directive:

.. code-block:: yaml

    /srv/stuff/substuf:
      file.directory:
        - user: fred
        - group: users
        - mode: 755
        - makedirs: True
        - recurse:
          - user
          - group
          - mode

As a default, ``mode`` will resolve to ``dir_mode`` and ``file_mode``, to
specify both directory and file permissions, use this form:

.. code-block:: yaml

    /srv/stuff/substuf:
      file.directory:
        - user: fred
        - group: users
        - file_mode: 744
        - dir_mode: 755
        - makedirs: True
        - recurse:
          - user
          - group
          - mode

Symlinks can be easily created; the symlink function is very simple and only
takes a few arguments:

.. code-block:: yaml

    /etc/grub.conf:
      file.symlink:
        - target: /boot/grub/grub.conf

Recursive directory management can also be set via the ``recurse``
function. Recursive directory management allows for a directory on the salt
master to be recursively copied down to the minion. This is a great tool for
deploying large code and configuration systems. A state using ``recurse``
would look something like this:

.. code-block:: yaml

    /opt/code/flask:
      file.recurse:
        - source: salt://code/flask
        - include_empty: True

A more complex ``recurse`` example:

.. code-block:: yaml

    {% set site_user = 'testuser' %}
    {% set site_name = 'test_site' %}
    {% set project_name = 'test_proj' %}
    {% set sites_dir = 'test_dir' %}

    django-project:
      file.recurse:
        - name: {{ sites_dir }}/{{ site_name }}/{{ project_name }}
        - user: {{ site_user }}
        - dir_mode: 2775
        - file_mode: '0644'
        - template: jinja
        - source: salt://project/templates_dir
        - include_empty: True
'''

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


def mycheck(name,
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


