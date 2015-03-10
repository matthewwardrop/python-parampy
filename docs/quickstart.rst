Quick Start
===========

In this section, the syntax of python-parameters for each major feature
is shown, along with simple examples of use within the python
interpreter. For the most part, the syntax should straightforward to use. 
If in doubt, refer to the API documentation in a subsequent chapter.

While the Parameters module is extremely flexible, allowing arbitrary unit definition
and non-dimensionalisation scalings, in most cases it should not be necessary to 
take advantage of this flexibility. Otherwise, there are two main classes that
are likely to be immediately useful to user:
	- :class:`SIQuantity` (a subclass of :class:`Quantity`)
	- :class:`Parameters`
:class:`Quantity` instances are the fundamental representation of physical
quantities in python-parameters, and the :class:`SIQuantity` subclass recognises
all SI units as well as some addition units the author found useful. For more 
information, see the API documentation in the next chapter. Instances of the Parameters class 
do the heavy lifting of managing potentially interdependent parameters and their
non-dimensionalisation (among other things). Both
of these classes can be imported from the parameters module using:

>>> from parameters import SIQuantity, Parameters

We will give a quick overview of their functionality in the following sections.

SIQuantity
----------

To create a SIQuantity object, we initialise it with a value and some valid units
(see the "Supported Units" chapter). The value specified can be any integer, float
or numpy array (or types conforming to standard python numeric operations). 
For example:

>>> q = SIQuantity(3, 'm*s')
>>> q
3 m*s
>>> r = SIQuantity(2.14, 'GN*nm')
>>> r
2.14 GN*nm

Arithmetic with SIQuantity instances is very simple, and support is
provided for unit conversion, addition, subtraction, multiplication,
division, raising to some power and equality tests. In cases where the
operation does not make sense, an exception is raised with details as to
why. Examples are now provided for each of these operations in turn.

>>> SIQuantity(3,'m/s^2')('in/ns^2') # Unit Conversion
1.1811023622e-16 in/ns^2

>>> SIQuantity(3,'m')+SIQuantity(2,'mm') # Addition
3.002 m

>>> SIQuantity(3,'kJ')-SIQuantity(2,'cal') # Subtraction
2.9916264 kJ

>>> SIQuantity(3.,'mT') / SIQuantity(10,'s') # Division
0.3 mT/s

>>> 2*SIQuantity(3.,'mT') # Scaling 
6.0 mT

>>> SIQuantity(2.6,'A')**2 # Squaring
6.76 A^2

>>> SIQuantity(1,'W*h') == SIQuantity(1e-9,'GW*h')
True

>>> SIQuantity(3,'m') + SIQuantity(2,'s') # Nonsense addition
UnitConversionError: Invalid conversion. Units 's' and 'm' do not match.

In each of the above examples, the returned object is another SIQuantity
object, which can also undergo further arithmetic operation. For
convenience, it is not necessary to manually instantiate all physical
quantities into SIQuantity objects; provided that at least one of the
operands involved in the calcuation is already an SIQuantity object. For
example, the addition example above could be simplified to:

>>> SIQuantity(3,'m')+(2,'mm') # Addition
3.002 m

>>> (3,'m')+SIQuantity(2,'mm') # Addition
3.002 m

Be careful when using this contraction that order of operations does not
cause the tuple to perform some undefined operation with something else.
For example:

>>> 2*(3,'m')+SIQuantity(2,'mm') # This becomes (3,'m',3,'m') + SIQuantity(2,'mm'), and fails

The Quantity class, which is the base class for the SIQuantity class is
quite flexible, and if you want to implement a non-SI system, or add
custom units, refer to the API documentation.

Parameters
----------

The Parameters class handles the heavy lifting of managing named
parameters, their values, relationships and conversions; using Quantity
objects to represent physical quantities. Initialising a Parameters
object is done using:

>>> p = Parameters()

There are three optional arguments that can be passed to this
initialiser:

-  default\_scaled=True: Whether parameters should return
   non-dimensionalised values instead of Quantity objects. By default,
   this is True. This can be negated at runtime.

-  constants=False: Whether to populate the parameter namespaces with
   various physical constants, all of which are prefixed with “c\_”
   (e.g. c\_hbar). By default, this is False.

-  dispenser=None: A custom UnitDispenser to use instead of the standard
   SI one. Most users will not need to touch this.

Unlike the :class:`SIQuantity` class, the :class:`Parameters` class has a lot of
power, and a lot of subtlety. If you are planning to use advanced features of the 
Parameters class (such as parameters depending on other parameters), 
it would probably be best to skip directly to the API documentation
for the :class:`Parameters` class, where everything is enumerated in detail.
In the next few subsections, only the basic functionality of this class will be 
explored. 

Parameter Definition
~~~~~~~~~~~~~~~~~~~~

Defining a parameter (all of the following are equivalent except when defining
parameters that are functions of others):

>>> p(x=(1.3,'kg*ns'))		# Method 1
>>> p << {'x': (1.3,'kg*ns')}	# Method 2
>>> p['x'] = (1.3,'kg*ns')	# Method 3
>>> p.x = (1.3,'kg*ns')		# Method 4

The first and second methods can be extended to add multiple parameters at once:

>>> p(x=1.3, y=2.1, z=4.1)
>>> p << {'x': 1.3, 'y': 2.1, 'z': 4.1}

Parameters can also be dependent on one another, by defining them as a function
or symbolic expression (as a string).

>>> p(x=lamda y,z: y**2 + z**2)			# Method 1
>>> p << {'x': 'y^2 + z^2'}		# Method 2
>>> p['x'] = lamda y,z: 'y^2 + z^2'		# Method 3
>>> p.x = lamda y,z: y**2 + z**2		# Method 4


Methods 1 & 3 evaluate the function **before** setting it as the value of the parameter,
whereas methods 2 & 4 cause the function to change with any future change in the 
underlying parameters. An exception will be raised if an attempt is made to cause
parameters to circularly depend on one another.

Parameter names can be any legal python variable name (except those
starting with an underscore). Parameter values can be any  numeric
type (including complex), any function/lambda object (or a string
representing a mathematical expression which is then converted to a
function), any tuple of preceeding types with a unit, and any Quantity
object.

To see a list of units stored in a :class:`Parameters` instance, use:

>>> p.show()

To remove a parameter definition, simply use the forget method:

>>> p.forget('x','y','z',...)

For more details, including how to make parameter dependencies invertible, 
to enforce bounds on parameters, and how to load and save parameters from a file,
please refer to the API documentation.

Parameter Extraction
~~~~~~~~~~~~~~~~~~~~

Extracting a parameter (all of the following methods are equivalent):

>>> p('x')	# Method 1
>>> p.x		# Method 2
>>> p['x']	# Method 3

By default, all returned units are non-dimensionalised first. To extract the physical
quantity as a :class:`Quantity` object, simply prepend the variable name with an
underscore.

>>> p('_x')
>>> p._x
>>> p['_x']

There is also a special fourth method for inverting the default behaviour and 
returning a Quantity object by default (and is otherwise like method 1).

>>> p._('x') # Method 4

Methods 1 & 4 can be used to extract more than one parameter at once, in which case
they are returned as a dictionary of values:

>>> p('x','y','z')
{'x': <value>, 'y': <value>, 'z': <value>}
>>> p._('x','y','z')
{'x': <quantity>, 'y': <quantity>, 'z': <quantity>}

Additionally, methods 1 & 4 can also temporarily override parameters as they 
extract the parameters, which is useful for testing how parameters behave in 
diferrent parameter contexts.

>>> p('x','y','z', k=<value>, l=<value>)
{'x': <value>, 'y': <value>, 'z': <value>}
>>> p._('x','y','z', k=<value>, l=<value>)
{'x': <quantity>, 'y': <quantity>, 'z': <quantity>}

For more information about extracting parameters, including parameter ranges, 
plotting, and more; please refer to the API documentation.

Unit Conversion
~~~~~~~~~~~~~~~

It is possible to use a :class:`Parameters` object for other tasks, such as unit
conversion. The syntax for this is:

>>> p.convert( <value>, input=<input units>, output=<output units>, value=<True/False> )

where *input* is the units that Parameters should assume the object has,
*output* is the desired output units, and *value* (with default True)
specifies whether or not you are only interested in its numerical
value, or whether a Quantity object should be returned. If not
specified, or equal to None, the input and output units are assumed to
refer to the non-dimensional quantities used by the Parameters object.

For example, the following command converts 1 ns to a non-dimensional quantity: 

>>> p.convert(1, input='ns')
1e-9

The following command converts 4 J to a value with units of calories:

>>> p.convert(4, input='J', output='cal')
0.9553835865099838

The following command converts 5 /day to a Quantity with units of years:

>>> p.convert(5, input='/day', output='/year', value=False)
1826.21095 /year

Note that this utility still works for Quantity units as well, in which
case the ‘input‘ argument is ignored, and read from the Quantity object.

>>> p.convert(SIQuantity(1,'km'),output='m')
1000.0
