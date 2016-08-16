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


@contextlib.contextmanager
def cd(directory):
    cwd = os.getcwd()
    os.chdir(directory)
    yield
    os.chdir(cwd)


def run():
    pass


def dub_cmd(build):
    return 'dub build --combined --parallel --build={}'.format(build)


def build_plugin(build, repo, outpath):
    author, name = repo.split('/')

    if not os.path.exists(name):
        os.popen('git clone --depth 1 git@github.com:{}.git'.format(repo))
    else:
        os.popen('git reset --hard')
        os.popen('git pull')

    with cd(name):
        os.popen(dub_cmd(build))

        if not os.path.exists('lib{}.so'.format(name)):
            print 'ERROR building {}: no plugin dynamic library found'.format(repo)
            return

        os.popen('mv lib{}.so {}'.format(name, outpath))


def build(build, plugins, directory):
    print 'Building with {} plugins...'.format(len(plugins))

    if not os.path.exists('plugins'):
        os.mkdir('plugins')

    if not os.path.exists(directory):
        os.mkdir(directory)

    plugin_path = os.path.join(os.getcwd(), 'plugins')

    with cd(directory):
        for plugin in plugins:
            print '  Building plugin {}...'.format(plugin)
            build_plugin(build, plugin, plugin_path)

    print '  Building jeff...'
    os.popen(dub_cmd(build))
    print 'DONE'


def main():
    args = parser.parse_args()

    build(args.build, args.plugin or [], args.build_dir)

    if args.run:
        run()

if __name__ == '__main__':
    sys.exit(main() or 0)
