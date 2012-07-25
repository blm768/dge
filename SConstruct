import fnmatch
import os

env = Environment(
	BINDIR = '../bin'
)

def find(path, pattern):
	matches = []
	for root, dirnames, filenames in os.walk(path):
		for filename in fnmatch.filter(filenames, pattern):
			matches.append(os.path.join(root, filename))
	return matches

dSources = find('.', '*.d')
libs = ['phobos-ldc', 'druntime-ldc', 'pthread', 'dl', 'rt', 'm']

test = env.Program(target = 'DGE', source = dSources, LIBS = libs, DC='ldc2')
