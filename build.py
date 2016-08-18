#!/usr/bin/env python
import os
import sys
import argparse
import contextlib

parser = argparse.ArgumentParser()
parser.add_argument('--plugin', action='append', help='additional plugins to build')
parser.add_argument('--build-dir', default='build', help='directory to build in')
parser.add_argument('--run', action='store_true', help='run after building')
parser.add_argument('--build', default='debug', help='dub build mode')
parser.add_argument('--update', default=False, action='store_true', help='update modules before building')
parser.add_argument('--force', default=False, action='store_true', help='force build')


@contextlib.contextmanager
def cd(directory):
    cwd = os.getcwd()
    os.chdir(directory)
    yield
    os.chdir(cwd)


def run():
    os.system("./jeff")


def dub_cmd(args):
    extras = ["--build={}".format(args.build)]
    if args.force:
        extras.append("--force")
    return 'dub build --combined --parallel {}'.format(' '.join(extras))


def build_plugin(plugin, plugin_path, command, update):
    print '  Building plugin {}...'.format(plugin)
    author, name = plugin.split('/')

    if not os.path.exists(name):
        os.popen('git clone --depth 1 git@github.com:{}.git'.format(plugin))
    elif update:
        with cd(name):
            os.popen('git reset --hard')
            os.popen('git pull')

    with cd(name):
        os.popen(command)

        if not os.path.exists('lib{}.so'.format(name)):
            print 'ERROR building {}: no plugin dynamic library found'.format(plugin)
            return

        os.popen('mv lib{}.so {}'.format(name, plugin_path))


def build(build, plugins, directory, update):
    print 'Building with {} plugins...'.format(len(plugins))

    if not os.path.exists('plugins'):
        os.mkdir('plugins')

    if not os.path.exists(directory):
        os.mkdir(directory)

    plugin_path = os.path.join(os.getcwd(), 'plugins')

    with cd(directory):
        for plugin in plugins:
            build_plugin(plugin, plugin_path, build, update)

    print '  Building jeff...'
    os.popen(build)
    print 'DONE'


def main():
    args = parser.parse_args()

    build(dub_cmd(args), args.plugin or [], args.build_dir, args.update)

    if args.run:
        run()

if __name__ == '__main__':
    sys.exit(main() or 0)
