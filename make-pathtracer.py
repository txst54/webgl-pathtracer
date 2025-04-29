import os
import glob
from distutils.dir_util import copy_tree
import shutil
import subprocess

srcfiles = glob.glob('./src/pathtracer/*.ts')
loaders = glob.glob('./src/lib/threejs/examples/jsm/loaders/*.js')
cmd = 'tsc --allowJs -m ES6 -t ES6 --outDir dist --sourceMap --alwaysStrict -w ' + " ".join(srcfiles) + ' ./src/lib/vue/vue.js ' + " ".join(loaders)
print('Building TypeScript: ' + cmd)
# os.system(cmd)
process = subprocess.Popen(cmd, shell=True)
copy_tree('./src/pathtracer/static', './dist')
process.wait()