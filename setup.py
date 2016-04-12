#!/usr/bin/env python2

from distutils.core import setup
from distutils.extension import Extension

try:
    from Cython.Distutils import build_ext
except ImportError:
    use_cython = False
else:
    use_cython = True

cmdclass = { }
ext_modules = [ ]

if use_cython:
    ext_modules += [
        Extension("parampy.parameters", [ "parampy/parameters.pyx" ]),
        Extension("parampy.errors", [ "parampy/errors.pyx" ]),
        Extension("parampy.physical_constants", [ "parampy/physical_constants.pyx" ]),
        Extension("parampy.quantities", [ "parampy/quantities.pyx" ]),
        Extension("parampy.text", [ "parampy/text.pyx" ]),
        Extension("parampy.units", [ "parampy/units.pyx" ]),
    ]
    cmdclass.update({ 'build_ext': build_ext })
else:
    ext_modules += [
        Extension("parampy.parameters", [ "parampy/parameters.c" ]),
        Extension("parampy.errors", [ "parampy/errors.c" ]),
        Extension("parampy.physical_constants", [ "parampy/physical_constants.c" ]),
        Extension("parampy.quantities", [ "parampy/quantities.c" ]),
        Extension("parampy.text", [ "parampy/text.c" ]),
        Extension("parampy.units", [ "parampy/units.c" ]),
    ]

setup(name='parampy',
      version='2.1.1',
      description='A parameter manager that keeps track of physical (or numerical) quantities, and the relationships between them.',
      author='Matthew Wardrop',
      author_email='mister.wardrop@gmail.com',
      url='http://www.matthewwardrop.info/',
      download_url='https://github.com/themadhatter/python-parampy',
      packages=['parampy','parampy.utility'],
      cmdclass = cmdclass,
      ext_modules = ext_modules,
      requires=['numpy','sympy(>0.7.5)','scipy'],
      license='''The MIT License (MIT)

Copyright (c) 2013 Matthew Wardrop

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.'''

     )
