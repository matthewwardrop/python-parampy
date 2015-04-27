ParamPy
=======

Keeping track of parameters during simulations can often be cumbersome, especially if those parameters are time-
or co- dependent, or if unit conversions are necessary. The `python-parameters` module solves this problem by acting
as a central repository of all parameters, their non-dimensionalisation, their interdependencies, their units and their
bounds. While providing all of this functionality, python-parameters also attempts to maintain minimal overhead so
that it is suitable for use in problems requiring iteration (such as numerical integration).

Properly enumerated, the classes in the `parampy` module can:
 - Act as a central location for the storage and retrieval of model parameters.
 - Keep track of parameter units, and perform unit conversions where that makes sense.
 - Perform non-dimensionalisation of parameters in a consistent fashion to allow for simple model simulations.
 - Allow parameters to inter-depend upon one another, and ensure that parameters do not depend upon one another
in unresolvable ways.
 - Allow parameters to depend on as-yet undeclared runtime values (such as integration time).
 - Keep track of limits for parameter values, to ensure parameters do not escape pre-defined parameter ranges.
 - Provide this functionality with minimal overhead to allow for speedy simulations.

As of version 1.9.0 (the version at time of writing); simple parameter storage and retrieval is only a factor of
≈7 slower than a python variable set and read; though speeds decrease depending upon how many of the more
sophisticated features are used (such as parameter bounding).

All features are documented, and most are unittested. For more information, refer
to `documentation.pdf`.

Installation
------------

In most cases, installing this module is as easy as:

	$ python2 setup.py install

If you run Arch Linux, you can instead run:

	$ makepkg -i
