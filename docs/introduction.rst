Introduction
------------

Keeping track of parameters during simulations can often be cumbersome,
especially if those parameters are time- or co- dependent, or if unit
conversions are necessary. `parampy` is a Python 2/3* module 
that abstracts the management of model parameters. It can:

 - Simplify the storage and retrieval of model parameters.
 - Keep track of parameter units, and perform unit conversions where that makes sense. It is also possible to provide/override unit definitions and conversions.
 - Perform non-dimensionalisation of parameters in a consistent fashion to allow for simpler model simulations.
 - Allow parameters to inter-depend upon one another, and ensure such dependencies are not recursive.
 - Allow parameters to depend on as-yet undeclared runtime values (such as integration time).
 - Keep track of limits for parameter values, to ensure parameters do not escape pre-defined parameter ranges (this slows down parameter evaluations significantly).
 - Provide a range of values sampled linearly, or with any custom distribution supplied.
 - Iterate over a (potentially nested) range of values of different parameters, and then execute a provided function in the new parameter context. By default, this execution is multi-threaded; but it may also be evaluated in a distributed manner on a cluster using a (slightly modified) version of dispy available at http://github.com/matthewwardrop/dispy.
 - Simplify parameters based upon whether or not certain parameters can be assumed to be fixed.
 - Run with low overhead so it is suitable for use in simulations in which parameters will be evaluated millions of times.

As of version 2.1.0 (the version at time of writing), simple parameter storage and extraction is only a factor of 8 ± 1 times slower than simply setting and reading a python variable (for Python 2*); though this increases when more advanced features are used. As a result, ParamPy ought not to be the bottleneck in simulations.

Most of the above features are thoroughly documented and unittested. Refer to `documentation.pdf` for more details.

 `*`: Python 3 support is new as of version 2.1.0 . ParamPy currently runs a little slower under Python 3 compared to Python 2.