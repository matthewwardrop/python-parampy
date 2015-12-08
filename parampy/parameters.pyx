from __future__ import print_function

from . import errors
from . import physical_constants
from .definitions import SIUnitDispenser
from .iteration import RangesIterator
from .quantities import Quantity
from .text import colour_text
from .units import Units, Unit
from .utility.compat import str_types

import copy
import imp
import inspect
import numpy as np
import re
import sympy
import sympy.abc
import types
import warnings


class Parameters(object):
	"""
	Parameters(dispenser=None, default_scaled=True, constants=False)

	:class:`Parameters` is the main class in the :mod:`parameters` package, and
	acts to organise and manage potentially interdependent physical quantities.
	The functionality of this class includes:

	- Non-dimensionalisation of parameters
	- Managing parameters which are functions of other parameters
	- Performing unit conversions of parameters
	- Iterating over ranges of parameters
	- Putting bounds on parameters

	A lot of the functionality of the :class:`Parameters` class is handled in
	"magic" methods, meaning that you will not necessarily find what you want to
	do by looking at the method documentation alone. In the rest of the class
	documentation, we cover the use of Parameters magic methods, alluding to
	the public methods where appropriate.

	:param dispenser: Should provide None or a custom unit dispenser. If None is
		provided, Parameters will instantiate an SIUnitDispenser; which hosts
		the standard units relative to an SI basis.
	:type dispenser: UnitDispenser or None
	:param default_scaled: :python:`True` when Parameters should by default return scaled non-dimensional parameters. :python:`False` otherwise.
	:type default_scaled: bool
	:param constants: :python:`True` when Parameters should import the physical constants when the internal :class:`UnitDispenser` is of type :class:`SIUnitDispenser`. :python:`False` otherwise.
	:type constants: bool

	Initialising a Parameters Instance:
		Initialising a :class:`Parameters` instance with the default configuration is simple:

		>>> p = Parameters()

		If you want to use your own :class:`UnitDispenser`, use united parameters
		by default, and preload the :class:`Parameters` instance with a set of
		physical constants, you could use:

		>>> u = SIUnitDispenser()
		>>> p = Parameters(dispenser=u, default_scaled=False, constants=True)

	Seeing what is stored in a Parameters instance:
		To see an overview of the parameter object; simply use:

		>>> p.show() # See show documentation for more.

		To get a list of parameters stored, use:

		>>> list(p)

		To check if a parameter is stored:

		>>> is_stored = 'x' in p # Will be True if 'x' is in p

	Parameter Definition:
		There are several ways to define parameters, each of which is shown below:

		>>> p(x=1)
		>>> p << {'x':1}
		>>> p['x'] = 1
		>>> p.x = 1

		The first two methods generalise to defining multiple parameters at once,
		whereas the second two do not. The first and third set parameters *after*
		first interpreting the value given (in a manner to be described below),
		whereas the others do not.

		.. note:: The last method will even when the parameter name clashes with a method of :class:`Parameters`, which you will be warned about when you define such a parameter. It will not be possible, however, to retrieve such a parameter using attribute notation later. Fortunately, "interpretation" makes no difference when retrieving parameters, and so the other methods will work as expected.

		Let us begin with the properties that all of these methods share.

		* Parameter names must start with a letter; and may contain any number of additional letters, numbers, and underscores.
		* Parameter values may be:
			- any numeric type (include :class:`complex`).
			- a string that represents a symbolic expression.
			- a function with zero or more arguments, each of which being the name of a parameter.
			- a two-tuple of any of the above types with a valid unit (see the Supported Units section of the Parameters documentation for supported SI units in a :class:`SIUnitDispenser`).
			- a :class:`Quantity` instance

		Here are some examples of valid parameter-value combinations:

		>>> p.x=1.42
		>>> p.alpha = 'sin(x)'
		>>> p.beta2 = lambda x, alpha: math.sqrt(x+alpha)
		>>> p.y = (32.1, '{mu}eV')
		>>> p.q_z_ = ('x+2*beta2', 'ms')

		When a unit is not specified, the parameter is assumed to be a
		scaled version of the parameter. If the unit has never been set,
		then a 'constant' unit is assumed; otherwise the older unit is assumed.

		You can specify the units of a parameter, without specifying its
		value:

		>>> p & {'x':'ms'}

		.. note:: If you do this when the parameter has already been set, the parameter value will be adjusted to maintain a constant physical value. If a parameter has been set, and you try to change the units to another which is dimensionally incompatible (e.g. 'm' -> 'ms'), this will result in a :python:`UnitConversionError` being raised. You should first ask the :class:`Parameters` instance to "forget" this value, as described shortly.

		Defining multiple parameters at once is easy with the first two methods:

		>>> p(x=1,y=(2,'s'),z=lambda x,y: x+y)
		>>> p << {'x':1,'y':(2,'s'),'z': lambda x,y: x+y }

		Note, though, that these two statements are **not** equivalent, as described
		in the next section.

	Interpreted vs Non-interpreted Parameter Definition:
		In the previous section, a distinction was made between methods of
		defining parameters that first "interpret" the value and those that do
		not. In particular: :python:`p(?=...)` and :python:`p[?] = ...` were said
		to first interpret the value, whereas :python:`p << {?: ...}` and
		:python:`p.? = ...` did not.

		The difference amounts to whether or not functions are first evaluated
		before being saved as a parameter value. For example:

		>>> p['x'] = lambda y: y**2 # Evaluated immediately
		>>> p.is_function('y')
		False
		>>> p.x = lambda y: y**2 # Evaluated only when x is determined
		>>> p.is_function('x')
		True

		Succinctly, interpreted parameter definitions set the parameter to the value
		of the function at time of definition; whereas non-interpreted parameter
		definitions cause the parameter to be evaluated in whatever context it finds
		itself in the future.

	Parameter Extraction:
		Just as there are several ways to define parameters, there are several
		ways to extract them. They are:

		>>> p('x')
		>>> p.x
		>>> p['x']

		Each of the above returns either a single non-dimensional value or a
		:class:`Quantity` depending upon whether default_scaled was passed as True
		or False respectively in the parameter instance. The first of these allows for multiple
		parameters to be extracted, whereas the second two do not. Additionally,
		the first of these also allows for temporarily overriding the parameter
		context. For example:

		>>> p('x','y',z=(10,'ms'))

		The above example returns a dictionary which contains a mapping from 'x'
		and 'y' to their respective values; evaluated in the context of 'z' being
		overridden temporarily with a value of 10 ms. At the end of this evaluation,
		'z' maintains whatever value it had before. This only affects the value
		of requested variables if it is a function of those variables.

		.. note:: As in most functions in this class that accept multiple parameter arguments, a dictionary is returned if there are two or more parameters; otherwise the value of the single requested parameter is returned. You can force a dictionary response by encapsulating this parameter in a list. For example::

			>>> p(['x'])

		As mentioned, if the :class:`Parameter` instance was instantiated with
		:python:`default_scaled` set to :python:`True`, then all of the parameters
		requested by name will return a non-dimensionalised number; or if it was
		:python:`False`, a :class:`Quantity` object. To invert this default, simply
		add a '_' to the variable name. For example:

		>>> p('_x')
		>>> p._x
		>>> p['_x']

		As a shorthand for extracting multiple parameters, you can use the following
		special method:

		>>> p._('x','y',z=(10,'ms'))

		This is identical in function to:

		>>> p('_x','_y',z=(10,'ms'))

		Although redundant, this special method can also set parameter values just
		as calling the :class:`Parameter` instance does:

		>>> p._(x=10)

	Parameter Interdependencies:
		As already discussed, parameters within a :class:`Parameters` instance
		can depend on values of other parameters by setting their value to be a
		function or symbolic expression. In this section we describe how to best
		take advantage of this functionality.

		Firstly, the function may either be a full function, method or lambda expression.

		Secondly, the function must take as arguments only parameter names which
		exist in the :class:`Parameters` instance at the time that it is executed.
		Thus, "non-interpreted" parameter definitions can be set to include variables
		that are only defined at runtime; such as the current time in a
		numerical integration. Beyond that, there are no restrictions, except that
		the function must return a value that is understood (this can both a numeric
		quantity, or a united quantity tuple, or a :class:`Quantity` object).

		Thirdly, by using a variable name prepended with an underscore in the
		function declaration, you can access both non-dimensional and dimensional
		quantities in your function.

		Fourthly, you can cause your function to be invertible by adding a reference
		to the variable name you are defining to the end of the list of function
		arguments, with a default value. When that variable is specified, you should
		return an ordered list/tuple of updated parameters for the other parameters in the
		function declaration. If there is only one other, it is sufficient to
		simply return it. For example:

		>>> p.x = lambda y,x=None: y**2 if x is None else x**0.5

		>>> p << {'y': 1, 'z': 1, 'x': lambda y,z,x=None: y+z if x is None else [y,x-y]}
		>>> p('x')
		2.0
		>>> p('z',x=10)
		9.0

		Lastly, parameter relationships can chained and as deep as you like.
		For example, x could depend on y, which could depend on z, and so on.
		The :class:`Parameters` will ensure that there are no dependency loops.

	Removing Parameters:
		To remove a parameter, simply use the forget method:

		>>> p.forget('x','y',...)

		As many parameters as you like can be specified in one function call.

	Parameter Units and Scaling:
		Custom units can be added by using the :func:`unit_add` method, and
		scaling used in the non-dimensionalisation process can be extracted
		for a given unit using the :func:`unit_scaling` method.

		You can customise the scaling used in the non-dimensionalisation process
		by changing the scaling of the various different dimensions using
		the :func:`scaling` method. By default, units are scaled relative
		to the SI fundamental units. The current scaling for a dimension
		can also be extracted using this function.

	Unit Conversion:
		Please see the documentation for the :func:`convert` method.

	Parameter Bounds:
		Please see the documentation for the :func:`bounds` and :func:`set_bounds`
		methods.

	Parameter Ranges:
		It is often useful to iterate over a range of parameter values. You can
		generate such ranges using the :func:`range` method. You can also have
		the iteration process handled for you, as documented in the
		:func:`range_iterator` method.

	Physical Constants:
		If :python:`constants` was :python:`True` when the :class:`Parameters`
		instance was initialised, and a :class:`SIUnitDispenser` is being used
		(as it is by default), then the parameter list is prepopulated with a list
		of physical constants. Please see the "Physical Constants" section of the
		*python-parameters* documentation.

	Loading and Saving Parameter Sets:
		To load a parameter set into a Parameters instance, use the classmethod
		:func:`load`. See its documentation for more information.

		To save your existing parameters, use:

		p >> "filename.py"

		Note that parameters that are dependent on other parameters will not survive
		this transition, and will be saved as static values.

	Parameter Contexts:
		Parameters objects support Python's "with" syntax. Upon exiting a "with"
		environment, any changes made will be reset to before re-entering the
		parent environment.

		>>> with p:
		>>> 	p(x=1)
		>>> p('x') # Returns value of x before entering the with environment.
	"""

	def __init__(self, dispenser=None, default_scaled=True, constants=False):
		self.__parameters_spec = {}
		self.__parameters = {}
		self.__parameters_bounds = None
		self.__scalings = {}
		self.__units = dispenser if dispenser is not None else SIUnitDispenser()
		self.__units_custom = []
		self.__default_scaled = default_scaled

		self.__cache_deps = {}
		self.__cache_sups = {}
		self.__cache_scaled = {}
		self.__cache_funcs = {}

		self.__scaling_cache = {}

		if constants and isinstance(self.__units, SIUnitDispenser):
			self(**physical_constants.constants)

	############## PARAMETER OBJECT CONFIGURATION ##############################
	def __add__(self, other):
		self.unit_add(other)
		return self

	def unit_add(self, *args, **kwargs):
		'''
		unit_add(*args, **kwargs)

		:param args: A length 1 sequence of Unit objects, or args to pass to the :class:`Unit` constructor.
		:type args: tuple of mixed type
		:param kwargs: Keyword arguments to pass to the :class:`Unit` constructor.
		:type kwargs: dict of mixed type

		This method allows you to add custom units to the :class:`UnitDispenser` object
		which generates :class:`Units` objects on demand. These additional units
		can override existing units, or add entirely new units. The :python:`args`
		and :python:`kwargs` passed to this function are essentially passed directly
		to the :class:`Unit` constructor:

		>>> Unit(*args, **kwargs)

		Unless:
		- :python:`args` contains a single :class:`Unit` instance, it is directly added the the :class:`UnitDispenser` used by :class:`Parameters`.
		- :python:`args` contains a single :class:`dict` instance, in which case the unit :python:`Unit(**args[0])` is add to the :class:`UnitDispenser`.

		For more information regarding the parameters which can passed to the :class:`Unit`
		constructor, see documentation for :class:`Unit`.
		'''
		if len(args) == 1:
			if isinstance(args[0], Unit):
				unit = args[0]
			elif isinstance(args[0], dict):
				unit = Unit(**args[0])
			else:
				raise ValueError("Invalid unit type to add: %s" % args[0])
		else:
			unit = Unit(*args, **kwargs)
		self.__units.add(unit)
		self.__units_custom.append(unit)

	def set_units_context(self, *name, **params):
		self.__units.set_context(*name,**params)

	@property
	def units_context(self):
		return self.__units.context

	def scaling(self, *args, **kwargs):
		'''
		scaling(*args, **kwargs)

		:param args: A (possibly empty) sequence of dimensions to query.
		:type args: tuple of str
		:param kwargs: A (possibly empty) specification of scales for various dimensions.
		:type kwargs: dict of str/Units

		:returns: The scaling associated with dimensions listed in :python:`args`.

		It is usually the case in numerical applications that one is only interested
		in dealing with non-dimensionalised quantities, rather than quantities
		with units. By default, Parameters instances will return non-dimensional
		quantities unless negated by the underscore (as described elsewhere).
		This method sets the reference scales which determine the
		non-dimensionalisation. By default, the SI fundamental units are used,
		as defined in :class:`SIUnitDispenser`.

		For example:

		>>> p.scaling(length='m') # This will set the base length unit to 'm'
		>>> p( (1,'m') )
		1.
		>>> p.scaling(time='ns') # This will set base time unit to 'ns'
		>>> p( (1,'s') )
		1e9

		Obviously, this does not affect units returned in united form.

		>>> p._( (1,'s') )
		1 s
		'''
		self.__scaling_cache = {}

		for arg in kwargs:
			if arg in self.__units.dimensions:
				scale = self.__get_quantity(kwargs[arg], param=arg)
				if scale.units.dimensions == {arg: 1}:
					self.__scalings[arg] = scale
				else:
					raise errors.ScalingUnitInvalidError("Dimension of scaling (%s) is wrong for %s." % (scale.units, arg))
			else:
				raise errors.ScalingDimensionInvalidError("Invalid scaling dimension %s." % arg)

		if len(args) == 1:
			return self.__scalings.get(args[0], Quantity(1, self.__units.basis()[args[0]], dispenser=self.__units))
		if len(args) > 0:
			output = {}
			for arg in args:
				output[arg] = self.__scalings.get(arg, Quantity(1, self.__units.basis()[arg], dispenser=self.__units))
			return output

	def unit_scaling(self, *params):
		'''
		unit_scaling(*params)

		:param params: A sequence of params for which to query internal non-dimensionalisation scaling.
		:type params: tuple

		:returns: A dictionary of unit scalings, or, if :python:`params` is of length 1, a single numeric scaling factor.

		This method returns the internal non-dimensionalisation factor used to
		scale united values. For example, using the default :class:`SIUnitDispenser`:

		>>> p.unit_scaling('m')
		1.0
		>>> p.unit_scaling('km')
		0.001
		>>> p.unit_scaling('eV')
		6.241509647120417e+18

		The results should be interpreted as: non-dim_value = united_value / unit_scaling .
		'''
		r = {}
		for param in params:
			r[param] = self.__unit_scaling(param)
		if len(params) == 1:
			return r[params[0]]
		return r

	def __get_unit(self, unit):

		if isinstance(unit, str_types):
			return self.__units(unit)

		elif isinstance(unit, Units):
			return unit

		raise errors.UnitInvalidError("No coercion for %s to Units." % unit)

	################## ENABLE USE WITH 'with' ####################################

	def __enter__(self):
		try:
			self.__context_save
		except:
			self.__context_save = []

		self.__context_save.append({
			'parameters_spec': copy.copy(self.__parameters_spec),
			'parameters': copy.copy(self.__parameters),
			'parameters_bounds': copy.copy(self.__parameters_bounds),
			'scalings': copy.copy(self.__scalings),
			'units': copy.copy(self.__units),
			'units_custom': copy.copy(self.__units_custom),
			'default_scaled': copy.copy(self.__default_scaled),
		})

	def __exit__(self, type, value, traceback):

		context = self.__context_save.pop()

		# Restore context
		self.__parameters_spec = context['parameters_spec']
		self.__parameters = context['parameters']
		self.__parameters_bounds = context['parameters_bounds']
		self.__scalings = context['scalings']
		self.__units = context['units']
		self.__units_custom = context['units_custom']
		self.__default_scaled = context['default_scaled']

		# Remove context
		if len(self.__context_save) == 0:
			del self.__context_save

		# Clear cache
		self.__cache_deps = {}
		self.__cache_sups = {}
		self.__cache_scaled = {}
		self.__scaling_cache = {}

	############# PARAMETER RESOLUTION #########################################
	def __get_pam_name(self, param):
		if isinstance(param, str_types):
			if param[:1] == "_":
				return param[1:]
			return param
		return param

	def __get_pam_scaled_name(self, param):
		param = self.__get_pam_name(param)
		if self.__default_scaled:
			return param
		return "_%s" % param

	def __get_pam_united_name(self, param):
		param = self.__get_pam_name(param)
		if not self.__default_scaled:
			return param
		return "_%s" % param

	def __get_pam_deps(self, param):
		try:
			return self.__cache_deps[param]
		except:
			if param not in self.__parameters:
				return []

			value = self.__parameters[param]
			if type(value) == types.FunctionType:
				self.__cache_deps[param] = list(map(self.__get_pam_name, self.__function_getargs(value)))
			else:
				self.__cache_deps[param] = []

			return self.__cache_deps[param]

	def __get_pam_sups(self, param):
		try:
			return self.__cache_sups[param]
		except:
			sups = []
			for param2 in self.__parameters:
				if param in self.__get_pam_deps(param2):
					sups.append(param2)

			if sups or param in self.__parameters:
				self.__cache_sups[param] = sups
			return sups

	############# PARAMETER RETRIEVAL ##########################################

	def __get(self, args, kwargs={}, default_scaled=None):
		'''
		Retrieve the parameters specified in args, with temporary values overriding
		defaults as in kwargs. Parameters are returned as Quantity's.
		'''
		self.__process_override(kwargs)

		arg_islist = type(args[0]) == list

		if len(args) == 1 and not arg_islist:
			result = self.__get_param(args[0], kwargs, default_scaled)
			if self.__parameters_bounds is not None:
				kwargs[args[0]] = result
				self.__forward_check_bounds(args, kwargs)
			return result

		if arg_islist:
			args = args[0]

		results = self.__get_params(args, kwargs, default_scaled)
		kwargs.update(results)
		if self.__parameters_bounds is not None:
			kwargs.update(results)
			self.__forward_check_bounds(args, kwargs)
		return results

	def __forward_check_bounds(self, args, kwargs):
		'''
		Check that bounds on parameters are not violated due to the changes
		specified in args and kwargs.
		'''
		checked = []
		for arg in args:
			if isinstance(arg, str_types):
				for pam in self.__get_pam_sups(arg):
					if pam in self.__parameters_bounds:
						keys = self.__get_pam_deps(pam)
						check = True
						for key in keys:
							if key not in kwargs and key not in self.__parameters:
								check = False
								break
						if check:
							self.__get_param(pam, kwargs)
						else:
							warnings.warn(errors.ParameterBoundsUncheckedWarning("Parameter '%s' might be outside bounds. Insufficient parameters passed to check." % pam))

	def __get_params(self, args, kwargs={}, default_scaled=None):
		rv = {}
		for arg in args:
			rv[self.__get_pam_name(arg)] = self.__get_param(arg, kwargs, default_scaled)
		return rv

	def __get_param(self, arg, kwargs={}, default_scaled=None):
		'''
		Returns the value of a param `arg` with its dependent variables overriden
		as in `kwargs`. If `arg` is instead a function, a string, or a Quantity, action is taken to
		evaluate it where possible.
		'''
		if arg == '_':
			raise ValueError()
		pam_name = self.__get_pam_name(arg)

		# If the parameter is actually a function or otherwise not directly in the dictionary of stored parameters
		if not isinstance(arg, str_types) or (pam_name not in kwargs and pam_name not in self.__parameters):
			return self.__eval(arg, kwargs, default_scaled)
		else:
			scaled = default_scaled if default_scaled is not None else self.__default_scaled
			if arg[:1] == "_":  # .startswith("_"):
				arg = arg[1:]
				scaled = not scaled

			# If the parameter is temporarily overridden, return the override value
			if arg in kwargs:
				return self.__get_quantity(kwargs[arg], param=arg, scaled=scaled)

			# If the parameter is a function, evaluate it with local parameter values (except where overridden in kwargs)
			elif type(self.__parameters[arg]) is types.FunctionType:
				return self.__get_quantity(self.__eval_function(arg, kwargs)[arg], param=arg, scaled=scaled)

			# Otherwise, return the value currently stored in the parameters
			else:
				if scaled:
					try:
						return self.__cache_scaled[arg]
					except:
						self.__cache_scaled[arg] = self.__get_quantity(self.__parameters[arg], param=arg, scaled=scaled)
						return self.__cache_scaled[arg]
				return self.__get_quantity(self.__parameters[arg], param=arg, scaled=scaled)

	def __process_override(self, kwargs, restrict=None):
		'''
		Process kwargs and make sure that if one of the provided overrides
		corresponds to an invertable function, that the affected variables are also included
		as overrides also. An warning is thrown if these variables are specified also
		and are inconsistent.
		'''

		if len(kwargs) == 0:
			return

		if restrict is None:
			restrict = list(kwargs.keys())

		if len(restrict) == 0:
			return

		def check_overspecified(param, kwargs, vals):
			return

		def pam_ordering(dependencies, pam_order=[]):
			'''
			This function returns parameter names in the following format:
			[ param_name, param_name, ...]
			Such that for any index, any parameters with greater index do
			not depend on parameters with index less than or equal to that index.
			'''
			new = set()
			for pam, deps in dependencies.items():
				if pam not in pam_order:
					for dep in deps:
						if dep not in pam_order and (dep not in dependencies or len(dependencies[dep].difference(set(pam_order)))):
							pam_order.append(dep)
							new.add(dep)
					if len(deps.difference(set(pam_order))) == 0:
						pam_order.append(pam)
						new.add(pam)

			if len(new) == 0 and len(set(dependencies.keys()).difference(set(pam_order))) != 0:
				raise ValueError("Function dependencies are circular.")
			elif len(new) == 0:
				return pam_order
			else:
				return pam_ordering(dependencies, pam_order)

		# Order overrides to avoid clash of functions
		dependencies = {}
		for pam in restrict:
			if pam[0] == "_":
				raise ValueError("Parameter type is autodetected when passed as a keyword argument. Do not use '_' to switch between scaled and unitted parameters.")
			val = kwargs[pam]
			if type(val) in str_types:
				val = self.__get_function(val)
				kwargs[pam] = val
			if type(val) is tuple and type(val[0]) is types.FunctionType:
				val = val[0]
			if type(val) is tuple and type(val[0]) in str_types:
				val = self.__get_function(val[0])
			if type(val) is types.FunctionType:
				pam = self.__get_pam_name(pam)
				deps = [self.__get_pam_name(dep) for dep in self.__function_getargs(val)]
				dependencies[pam] = set(deps)

		pam_order = pam_ordering(dependencies)

		# First evaluate functions to avoid errors later on
		for pam in pam_order:
			if pam in kwargs:
				val = kwargs[pam]
				new = kwargs.copy()
				del new[pam]
				kwargs[pam] = self.__get_param(val, new)

		# Now, ratify these changes through the parameter sets to ensure
		# that the effects of these overrides is properly implemented
		# inverting any methods with the provided overrides
		# and then recursing on any newly returned values.
		# If a method is not invertible, and it is request,
		# print a warning to this extent.
		new = {}
		for pam in restrict:
			if type(self.__parameters.get(pam)) is types.FunctionType:
				if pam in self.__get_pam_deps(pam):
					vals = self.__eval_function(pam, kwargs)
					for key in vals:
						if key in kwargs and self.__get_quantity(vals[key],scaled=True) != self.__get_quantity(kwargs[key],scaled=True) or key in new and self.__get_quantity(vals[key],scaled=True) != self.__get_quantity(new[key],scaled=True):
							raise errors.ParameterOverSpecifiedError("Parameter %s is overspecified, with contradictory values. (%s vs. %s)" % (key,vals[key],kwargs[key] if key in kwargs else new[key]) )
					new.update(vals)
				else:
					warnings.warn(errors.ParameterInconsistentWarning("Parameters are possibly inconsistent! The function representing '%s' was overridden because it was not invertable, and so the underlying variables (%s) have not been updated." % (pam, ','.join(self.__function_getargs(self.__parameters[pam])))))

		if len(new) != 0:
			kwargs.update(new)
			self.__process_override(kwargs, restrict=list(new.keys()))

	def __eval_function(self, param, kwargs={}):
		'''
		Returns a dictionary of parameter values. If the param variable itself is provided,
		then the function has its inverse operator evaluated. Functions must be of the form:
		def f(<pam>,<pam>,<param>=None)
		If <pam> is prefixed with a "_", then the scaled version of the parameter is sent through
		instead of the Quantity version.
		'''

		f = self.__parameters.get(param)
		deps = self.__get_pam_deps(param)
		deps_ = self.__function_getargs(f)

		# Check if we are inverting or evaluating (if param is in kwargs, we are inverting), and prepare.
		if param in kwargs:
			if deps[-1] != param:
				raise errors.ParameterNotInvertableError("Configuration requiring the inverting of a non-invertable map for %s." % param)
		else:
			if deps[-1] == param:
				deps = deps[:-1]
				deps_ = deps_[:-1]

		# Compute required arguments for functional argument
		params = self.__get_params(deps_, kwargs)
		args = [val for val in [params[self.__get_pam_name(x)] for x in deps_]]

		if param in kwargs: # Invert and return updated parameter values
			r = f(*args)
			if type(r) not in (list,tuple):
				r = (r,)

			inverse = {}

			for i, arg in enumerate(deps[:-1]): # Iterate through results except for final dep which is param or _param
				pam = self.__get_pam_name(arg)
				inverse[pam] = self.__get_quantity(r[i], param=pam)

			return inverse
		else: # Return value of function (from cache if possible)
			if param in self.__cache_funcs:
				cached = self.__cache_func_handler(param=param, params=args)
				if cached is not None:
					return {param: cached}
				else:
					value = f(*args)
					self.__cache_func_handler(param=param, value=value, params=args)
					return {param: value}
			else:
				return {param: f(*args)}


	def __cache_func_handler(self, param, value=None, params=None):
		'''
		Retrieve and set function cache.
		'''
		if param in self.__cache_funcs:
			if value is None:
				if self.__cache_funcs[param] is None:
					return None
				value, conditions = self.__cache_funcs[param]
				if conditions == params:
					return value
				else:
					return None
			else:
				self.__cache_funcs[param] = (value, params)

	def cache(self, **kwargs):
		'''
		cache(**kwargs)

		:param kwargs: Dictionary of boolean values
		:type kwargs: :class:`dict`

		A utility function to toggle caching of particular parameters. When
		cache is enabled, if a parameter function has been called before with the
		same parameter values, then it returns the old value. Note that only
		one set of parameters is remembered, and so this caching is designed
		only for situations where the parameter is not expected to change at
		every call.

		Example:

		>>> p.cache(x=True, y=False)

		This will enable caching for *x* and disable it for *y*.
		'''
		for kwarg, cache_on in kwargs.items():
			if kwarg in self.__cache_funcs and not cache_on:
				self.__cache_funcs.pop(kwarg)
			if kwarg not in self.__cache_funcs and cache_on:
				self.__cache_funcs[kwarg] = None

	def __get_quantity(self, value, param=None, unit=None, scaled=False):
		'''
		Return a Quantity or scaled float associated with the value provided
		and the dimensions of param.
		'''

		q = None

		t = type(value)

		if t is types.FunctionType:
			return value
		else:
			if scaled:

				# If tuple of (value,unit) is presented
				if t is tuple:
					if len(value) != 2:
						raise errors.QuantityCoercionError("Tuple specifications of quantities must be of form (<value>,<unit>). Was provided with %s ." % str(value))
					else:
						q = Quantity(value[0], value[1], dispenser=self.__units)
						q = q.value / self.__unit_scaling(q.units)

				elif isinstance(value, Quantity):
					q = value.value / self.__unit_scaling(value.units)

				else:  # if t in (float,complex,long,int,np.ndarray):
					q = value

			else:

				# If tuple of (value,unit) is presented
				if t is tuple:
					if len(value) != 2:
						raise errors.QuantityCoercionError("Tuple specifications of quantities must be of form (<value>,<unit>). Was provided with %s ." % str(value))
					else:
						q = Quantity(value[0], value[1], dispenser=self.__units)

				elif isinstance(value, Quantity):
					q = value

				else:  # if t in (float,complex,long,int,np.ndarray):
					if unit is None and param is None:
						unit = self.__get_unit('')
					elif unit is not None:
						unit = self.__get_unit(unit)
					else:
						unit = self.__get_unit(''  if self.__parameters_spec.get(param) is None else self.__parameters_spec.get(param))
					if isinstance(value, list):
						value = np.array(value)
					q = Quantity(value * self.__unit_scaling(unit), unit, dispenser=self.__units)

		if q is None:
			raise errors.QuantityValueError("Unknown value type '%s' with value: '%s'" % (t, value))

		if self.__parameters_bounds is not None and param is not None and param in self.__parameters_bounds:
			q = self.__check_bounds(self.__parameters_bounds[param], q)

		return q

	def __eval(self, arg, kwargs={}, default_scaled=None):

		if default_scaled is None:
			default_scaled = self.__default_scaled

		t = type(arg)

		if t == tuple:
			return self.__get_quantity((self.__eval(arg[0], kwargs), arg[1]), scaled=default_scaled)

		elif t == types.FunctionType:
			deps = self.__function_getargs(arg)
			params = self.__get_params(deps, kwargs)
			args = [val for val in [params[self.__get_pam_name(x)] for x in deps]]  # Done separately to avoid memory leak when cythoned.
			return arg(*args)

		elif isinstance(arg, Quantity):
			return self.__get_quantity(arg, scaled=default_scaled)

		elif isinstance(arg, str_types) or arg.__class__.__module__.startswith('sympy'):
			try:
				if isinstance(arg, str_types):
					# We have a string which cannot be a single parameter. Check to see if it is trying to be.
					arg = sympy.S(arg, sympy.abc._clash)
					fs = list(arg.free_symbols)
					if len(fs) == 1 and str(arg) == str(fs[0]):
						raise errors.ParameterInvalidError("There is no parameter, and no interpretation, of '%s' which is recognised by Parameters." % arg)
				return self.__eval(self.optimise(arg), kwargs=kwargs, default_scaled=default_scaled)
			except errors.ParameterInvalidError as e:
				raise e
			except Exception as e:
				raise errors.SymbolicEvaluationError("Error evaluating symbolic statement '%s'. The message from SymPy was: `%s`." % (arg, e))

		elif isinstance(arg, (complex, int, float, long)):
			return arg

		raise errors.ParameterInvalidError("There is no parameter, and no interpretation, of '%s' which is recognised by Parameters." % arg)

	################ SET PARAMETERS ############################################

	def __is_valid_param(self, param, allow_leading_underscore=True):
		return re.match("^[%sA-Za-z][_a-zA-Z0-9]*$" % ('_' if allow_leading_underscore else ''), param)

	def __check_valid_params(self, params, allow_leading_underscore=True):
		bad = []
		for param in params:
			if not self.__is_valid_param(param, allow_leading_underscore=allow_leading_underscore):
				bad.append(param)
		if len(bad) > 0:
			raise errors.ParameterInvalidError("Attempt to set invalid parameters: %s . Parameters must be valid python identifiers matching ^[%sA-Za-z][_a-zA-Z0-9]*$." % (','.join(bad), '_' if allow_leading_underscore else ''))

	def __set(self, kwargs):

		self.__cache_deps = {}
		self.__cache_sups = {}

		self.__check_valid_params(kwargs, allow_leading_underscore=False)

		for param, val in kwargs.items():
			if param in self.__cache_funcs:
				self.__cache_funcs[param] = None
			if param in self.__cache_scaled:  # Clear cache if present.
				del self.__cache_scaled[param]
			if isinstance(val, (types.FunctionType,) + str_types):
				self.__parameters[param] = self.__check_function(param, self.__get_function(val))
				self.__spec({param: self.__get_unit('')})
			elif isinstance(val, (list, tuple)) and isinstance(val[0], (types.FunctionType,) + str_types):
				self.__parameters[param] = self.__check_function(param, self.__get_function(val[0]))
				self.__spec({param: self.__get_unit(val[1])})
			else:
				self.__parameters[param] = self.__get_quantity(val, param=param)
				if isinstance(self.__parameters[param], Quantity):
					self.__spec({param: self.__parameters[param].units})
			if param in dir(type(self)):
				warnings.warn(errors.ParameterNameWarning("Parameter '%s' will not be accessible using the attribute notation `p.%s`, as it conflicts with a method name of Parameters." % (param, param)))

	def __update(self, kwargs):

		self.__check_valid_params(kwargs)

		self.__process_override(kwargs)

		for param, value in kwargs.items():
			if param not in self.__parameters or not (isinstance(self.__parameters.get(param), types.FunctionType) and param in self.__get_pam_deps(param)):
				self.__set({param: kwargs[param]})

	def __and__(self, other):
		if not isinstance(other, dict):
			raise errors.ParametersException("The binary and operator is used to set the unit specification for parameters; and requires a dictionary of units.")
		for param, units in other.items():
			if isinstance(self.__parameters.get(param), Quantity):
				self.__parameters[self.__get_pam_name(param)] = self.__get_param(self.__get_pam_united_name(param))(units)
		self.__spec(other)

	def __spec(self, kwargs):
		''' Set units for parameters. '''
		for arg in kwargs:
			self.__parameters_spec[arg] = self.__get_unit(kwargs[arg])
			if self.__parameters.get(arg) is not None:
				self.__parameters[arg].units = self.__parameters_spec[arg]

	def __remove(self, param):
		if param in self.__parameters:
			del self.__parameters[param]
		if param in self.__parameters_spec:
			del self.__parameters_spec[param]

	def forget(self, *params):
		'''
		forget(*params)

		:param params: List of parameter names to forget.
		:type params: :class:`tuple` of :class:`str`

		:returns: A reference to the parent :class:`Parameters` instance.

		This is the way to remove parameters that are stored inside a :class:`Parameters`
		instance.

		Example:

		>>> p.forget('x','y','z')

		This removes parameters *x*, *y* and *z* from the parameter list.
		'''
		for param in params:
			self.__remove(param)
		return self

	def __sympy_to_function(self, expr):
		try:
			expr = sympy.S(expr, locals=sympy.abc._clash)
			syms = list(expr.free_symbols)
			f = sympy.utilities.lambdify(syms, expr, dummify=False, modules=['numpy','mpmath','math','sympy'])
			return f
		except Exception, e:
			print(e)
			raise errors.SymbolicEvaluationError('String \'%s\' is not a valid symbolic expression.' % (expr))

	def __get_function(self, expr):
		if isinstance(expr, types.FunctionType):
			return expr
		return self.__sympy_to_function(expr)

	def __check_function(self, param, f, forbidden=None):

		_param = '_' + param

		inspection = inspect.getargspec(f)
		if inspection.varargs is not None or inspection.keywords is not None:
			raise ValueError("Cannot add parameter function that uses varargs or keyword arguments for '%s'." % param)
		if (param in inspection.args and inspection.args.index(param) != len(inspection.args) - 1) or (_param in inspection.args and inspection.args.index(_param) != len(inspection.args) - 1):
			raise ValueError("Self-reference for inversion must be the last parameter provided in args for '%s'." % param)
		if (param in inspection.args or _param in inspection.args)and inspection.defaults != (None,):
			raise ValueError("Cannot add parameter function that does not set a default value of None for self-referential parameter in definition for '%s'." % param)
		if param not in inspection.args and _param not in inspection.args and inspection.defaults != None:
			raise ValueError("Cannot add parameter function that provides default values for parameters in '%s'." % param)

		args = list(self.__function_getargs(f))

		if param in args:
			args.remove(param)

		if forbidden is None:
			forbidden = []
		else:
			for arg in forbidden:
				if arg in args:
					raise errors.ParameterRecursionError("Adding function would result in recursion with function '%s'" % arg)
		forbidden.append(param)

		for arg in args:
			if isinstance(self.__parameters.get(arg, None), types.FunctionType):
				self.__check_function(arg, self.__parameters.get(arg), forbidden=forbidden[:])

		return f

	def __function_getargs(self, f):  # faster than inspect.getargspec(f).args
		return f.__code__.co_varnames[:f.__code__.co_argcount]

	def __basis_scale(self, unit):
		unit = self.__get_unit(unit)
		scaling = Quantity(1, None, dispenser=self.__units)

		for dim, power in unit.dimensions.items():
			scaling *= self.__scalings.get(dim, Quantity(1, self.__units.basis()[dim], dispenser=self.__units)) ** power

		return scaling

	def __unit_scaling(self, unit):
		'''
		Returns the float that corresponds to the relative scaling of the
		provided unit compared to the intrinsic scaling basis of the parameters.

		dimensionless value = quantity / unit_scaling = quantity * unit_scale / basis_scale
		'''

		if unit in self.__scaling_cache:
			return self.__scaling_cache[unit]

		scale = self.__basis_scale(unit)
		scaling = scale.value * scale.units.scale(unit)

		self.__scaling_cache[unit] = scaling
		return scaling

	################ EXPOSE PARAMETERS #########################################
	def __call__(self, *args, **kwargs):
		if args:
			return self.__get(args, kwargs)

		self.__update(kwargs)
		return self

	def _(self, *args, **kwargs):
		if args:
			return self.__get(args, kwargs, not self.__default_scaled)

		self.__update(kwargs)
		return self

	def __getattr__(self, name):
		if name[:2] == "__" or name[:11] == "_Parameters":
			raise AttributeError()
		return self.__get_param(name)

	def __setattr__(self, attr, value):
		if attr.startswith('__') or attr.startswith('_Parameters'):
			return super(Parameters, self).__setattr__(attr, value)
		return self.__set({attr: value})

	def __lshift__(self, other):

		if not isinstance(other, dict):
			raise errors.ParametersException("The left shift operator sets parameter values without interpretation; such as functions. It accepts a dictionary of parameter values.")

		self.__set(other)
		return self

	def __dir__(self):
		res = dir(type(self)) + list(self.__dict__.keys())
		res.extend(self.__parameters.keys())
		return res

	################# Other Magic ##############################################
	def __repr__(self):
		return "< Parameters with %d definitions >" % len(self.__parameters)

	def __len__(self):
		return len(self.__parameters)

	def __iter__(self):
		params = sorted(self.__parameters.keys())
		for param in params:
			yield param

	def __getitem__(self, key):
		if type(key) == int:
			return sorted(self.__parameters.keys())[key]
		return self.__get(key)

	def __setitem__(self, key, value):
		self.__update({key: value})

	################# Show parameters ########################################

	def __table(self, table):

		def text_len(text):
			if '\033[' in text:
				return len(text) - 11
			return len(text)

		def column_width(i, text):
			if '\033[' in text:
				return col_width[i] + 11
			return col_width[i]

		col_width = [max(text_len(x) for x in col) for col in zip(*table)]
		output = []
		for line in table:
			output.append("| " + " | ".join("{:^{}}".format(x, column_width(i, x)) for i, x in enumerate(line)) + " |")

		return '\n'.join(output)

	def show(self):
		'''
		show(self)

		This method simply prints a formatted table of parameters stored in the
		:class:`Parameters` instance. It shows the parameter and its dependencies,
		its united value, and its non-dimensionalised value.

		To use it, simply run:

		>>> p.show()
		'''
		if len(self.__parameters) == 0:
			return 'No parameters have been specified.'

		parameters = [[colour_text('Parameter', 'WHITE', True), colour_text('Value', 'WHITE', True), colour_text('Scaled', 'WHITE', True)]]
		for param in sorted(self.__parameters.keys()):

			if self.__default_scaled:
				key_scaled, key = param, '_%s' % param
			else:
				key_scaled, key = '_%s' % param, param

			if isinstance(self.__parameters[param], types.FunctionType):
				v = 'Unknown'
				vs = 'Unknown'
				try:
					v = str(self.__get_param(key))
					vs = str(self.__get_param(key_scaled))
				except:
					pass
				parameters.append([
					'%s(%s)' % (param, ','.join(self.__get_pam_deps(param))),
					v,
					vs])

			else:
				parameters.append([param, str(self.__get_param(key)), str(self.__get_param(key_scaled))])

		for param in sorted(self.__parameters_spec.keys()):
			if param not in self.__parameters:
				parameters.append([colour_text(param, 'CYAN'), colour_text("- %s" % self.__parameters_spec[param], 'CYAN'), colour_text("-", 'CYAN')])

		print(self.__table(parameters))

	################## PARAMETER BOUNDS ####################################

	def bounds(self, *params, **bounds):
		'''
		bounds(*params, **bounds)

		:param params: Sequence of parameter names for which to query the bounds.
		:type param: tuple
		:param bounds: Dictionary specifying parameter bounds to be applied.
		:type bounds: dict

		:returns: Dictionary of :class:`Bound` objects, or, if only one parameter is specified, then just one :class:`Bound` object. If no bounds exist for a parameter, :python:`None` is returned.

		This method allows you to simply query and set bounds on parameters. For
		more advanced bounds setting, you should use :func:`set_bounds`. For each
		parameter, valid bounds are specified by a two-tuple, or a list of two-tuples.
		If one of the extremum values is None, it is set to -infinity or +infinity, depending upon
		whether it is the upper or lower bound.

		For example:

		>>> p.bounds(x=(0,100)) # Bounds x between 0 and 100 inclusive.

		>>> p.bounds(y=[(0,50),(150,200)]) # Bounds y between 0-50 or between 150-200.

		>>> p.bounds('x') # Returns the Bounds object associated with x

		>>> p.bounds('x',x=(0,None)) # Sets the bounds on x to be [0,+inf], and then returns the :class:`Bounds` object associated with x.

		Note that multiple parameters can be queried and set at the same time.

		.. warning:: Using parameter bounds greatly increases the amount of computation done during parameter retrieval. It is recommended that you do not use parameter bounds in contexts which require minimal runtime, such as numerical integration.
		'''
		self.set_bounds(bounds)

		if len(params) > 0:
			use_dict = type(params[0]) == list
			if use_dict:
				params = params[0]

			bounds = {}
			for param in params:
				bounds[param] = self.__parameters_bounds[param].bounds if param in self.__parameters_bounds else None
			if not use_dict and len(bounds) == 1:
				return bounds[list(bounds.keys())[0]]
			return bounds

	def set_bounds(self, bounds_dict, error=True, clip=False, inclusive=True):
		'''
		set_bounds(bounds_dict, error=True, clip=False, inclusive=True)

		:param bounds_dict: A dictionary with parameters as keys with a valid bounding specification (described below).
		:type bounds_dict: dict
		:param error: :python:`True` if a parameter found to be outside specified bounds throw an error; or if :python:`clip` is :python:`True`, whether a warning should be generated. :python:`False` otherwise.
		:type error: bool
		:param clip: :python:`True` if the relevant parameter should be clipped to the nearest bound edge (assumes inclusive is True). :python:`False` otherwise.
		:type clip: bool
		:param inclusive: :python:`True` if the upper and lower bounds should be included in range. :python:`False` otherwise.
		:type inclusive: bool

		This method provides you with greater control than the shorthand methods
		described in the class documentation. As a reminder the shorthand methods
		looked like:

		>>> p[’x’] = (0,100)

		If one of the extremum values is None, it is set to -infinity or +infinity, depending upon
		whether it is the upper or lower bound. If a disjointed bound is necessary, you can use:

		>>> p[’x’] = [ (None,10), (15,None) ]

		This method is much more flexible; for example:

		>>> p.set_bounds( {'x':(0,100)}, error=True, clip=True, inclusive=True )

		Will warp 'x' to the closer of 0 or 100 if outside of the range [0,100],
		reporting a warning in the process.

		.. warning:: Using parameter bounds greatly increases the amount of computation done during parameter retrieval. It is recommended that you do not use parameter bounds in contexts which require minimal runtime, such as numerical integration.
		'''
		if not isinstance(bounds_dict, dict):
			raise ValueError("Bounds must be specified as a dictionary. Provided with: '%s'." % (bounds_dict))
		for key, bounds in bounds_dict.items():
			if not isinstance(bounds, list):
				bounds = [bounds]
			bounds_new = []
			for bound in bounds:
				if not isinstance(bound, tuple) or len(bound) != 2:
					raise ValueError("Bounds must be of type 2-tuple. Received '%s'." % (bound))

				lower = bound[0]
				if lower is None:
					lower = (-np.inf, self.units(key))
				lower = self.__get_quantity(lower, param=key)

				upper = bound[1]
				if upper is None:
					upper = (np.inf, self.units(key))
				upper = self.__get_quantity(upper, param=key)
				bounds_new.append((lower, upper))

			if self.__parameters_bounds is None:
				self.__parameters_bounds = {}
			self.__parameters_bounds[key] = Bounds(key, self.units(key), bounds_new, error=error, clip=clip, inclusive=inclusive)

	def __check_bounds(self, bounds, value):
		if isinstance(value, Quantity):
			scaled = False
			value_comp = value
		else:
			scaled = True
			value_comp = Quantity(value, self.__parameters_spec.get(bounds.param, None), dispenser=self.__units)

		if bounds.inclusive:
			for bound in bounds.bounds:
				if bound[0] <= value_comp and bound[1] >= value_comp:
					return value
		else:
			for bound in bounds.bounds:
				if bound[0] < value_comp and bound[1] > value_comp:
					return value

		if bounds.clip:
			if bounds.error:
				warnings.warn(errors.ParameterOutsideBoundsWarning("Value %s for '%s' outside of bounds %s. Clipping to nearest allowable value." % (value, bounds.param, bounds.bounds)))
			blist = []
			for bound in bounds.bounds:
				blist.extend(bound)
			dlist = map(lambda x: abs(x - value_comp), blist)
			v = np.array(blist)[np.where(dlist == np.min(dlist))]
			if scaled:
				return v
			else:
				return v.value / self.__unit_scaling(v.unit)
		elif bounds.error:
			raise errors.ParameterOutsideBoundsError("Value %s for '%s' outside of bounds %s" % (value, bounds.param, bounds.bounds))

		warnings.warn(errors.ParameterOutsideBoundsWarning("Value %s for '%s' outside of bounds %s. Using value anyway." % (value, bounds.param, bounds.bounds)))
		return value

	################## RANGE UTILITY #######################################

	def range(self, *args, **ranges):
		'''
		range(*args, **ranges)

		:param args: A sequence of parameters (or parameter expressions).
		:type args: tuple
		:param ranges: A dictionary of overrides and range specifications.
		:type ranges: dict

		:returns: A sequence of parameter values if there is a single parameter requested and it is not enclosed in a list, and dictionary of values otherwise.

		This method provides a solution to the common problem of iterating over
		parameter ranges, or investigating how one parameter changes as a function
		of another. It has a similar syntax for parameter extraction by calling
		the :class:`Parameter` instance, and indeed provides a superset of the
		functionality. It is kept separate for peformance considerations.

		One can think about the syntax of this method as overriding the parameter
		value with a sequence of values, rather than a specific value. For example:

		>>> p << {'y':lamdba x:x**2}
		>>> p.range( 'y', x = [0,1,2,3] )
		[0,1.,4.,9.]

		In this simple example, we see that we can iterate over a provided array of
		values. Arrays may be input as lists or numpy ndarrays; and returned arrays are typically numpy arrays.

		The values for parameter overrides can also be provided in a more abstract notation; such that the
		range will be generated when the function is called. Parameters accepts ranges in the following
		forms:

			- (*<start>*, *<stop>*, *<count>*) : which will generate a linear array from <start> to <stop> with <count> values.
			- (*<start>*, *<stop>*, *<count>*, ..., *<sampler>*) : which is as above, but where the <sampler> is expected to generate the array. <sampler> can be a string (either ‘linear’,’log’,’invlog’ for linear, logarithmic, or inverse logarithmic distributions respectively); or a function which takes arguments <start>, <stop>, <count> and any other arguments from "...". Note that when you specify your own function, the <start>, <stop> and <count> variables need not be interpreted as their name suggests.

		Example:

		>>> p.range( 'y', x = (0,10,2) )
		[0.,100.]

		It is also possible to determine multiple parameters at once.

		>>> p.range( ‘x’, ‘y’, x=(0,10,2) )
		{'x':[0.,10.], 'y':[0.,100.]}

		If multiple overrides are provided, they must either be constant or have the same length.

		>>> p.range('x', x=(0,10,2), z=1 ) # This is OKAY

		>>> p.range('x', x=(0,10,2), z=[3,4]) # This is also OKAY

		>>> p.range( 'x', x=(0,10,2), z=[1,2,3] ) # This is NOT okay.
		'''

		if len(args) == 0:
			raise ValueError('Please specify output variables from ranges.')

		values = None
		static = {}
		lists = {}

		# Separate out static coefficients
		for param, pam_range in ranges.items():
			if not isinstance(pam_range, (list, np.ndarray, tuple)) or type(pam_range) is tuple and len(pam_range) < 3:  # Using negated check to maximise allowed input types.
				static[param] = pam_range

		# Generate sequences in the context of static coefficients
		# Note: It is not necessary to worry about clashes at this
		#       stage. They will be detected in the self.__get() method.
		count = None
		for param, pam_range in ranges.items():
			pam_range = self.__range_interpret(param, pam_range, params=static)
			if isinstance(pam_range, (list, np.ndarray)):
				lists[param] = pam_range
				count = len(pam_range) if count is None else count
				if count != len(pam_range):
					raise ValueError("Not all parameters have the same range")

		if count is None:
			return self.__get(args, ranges)

		if type(args[0]) == list:
			pargs = args[0]
		else:
			pargs = args

		for i in range(count):
			d = {}
			d.update(static)
			for key in lists:
				d[key] = lists[key][i]

			argvs = self.__get(args, d)

			if type(argvs) == dict:
				if values is None:
					values = {}
				for arg in argvs:
					if arg not in values:
						values[arg] = []
					values[arg].append(argvs[arg])
			else:
				if values is None:
					values = []
				values.append(argvs)

		return values

	def __range_sampler(self, sampler):
		if isinstance(sampler, str_types):
			if sampler == 'linear':
				return np.linspace
			elif sampler == 'log':
				def logspace(start, end, count):
					logged = np.logspace(1, 10, count)
					return (logged - logged[0]) * (end - start) / logged[-1] + start
				return logspace
			elif sampler == 'invlog':
				def logspace(start, end, count):
					logged = np.logspace(1, 10, count)
					return (logged[::-1] - logged[0]) * (end - start) / logged[-1] + start
				return logspace
			else:
				raise ValueError("Unknown sampler: %s" % sampler)
		elif type(sampler) == types.FunctionType:
			return sampler
		else:
			raise ValueError("Unknown type for sampler: %s" % type(sampler))

	def __range_interpret(self, param, pam_range, params=None):
		if isinstance(pam_range, tuple) and len(pam_range) >= 3:

			if len(pam_range) >= 4:  # Then assume format (*args, sampler), with sampler(*args) being the final result.
				args = list(pam_range[:-1])
				sampler = pam_range[-1]
			elif len(pam_range) == 3:  # Then assume format (start, end, count)
				args = list(pam_range)
				sampler = 'linear'
			else:
				raise ValueError("Unknown range specification format: %s." % pam_range)

			sampler = self.__range_sampler(sampler)

			for i, arg in enumerate(args):
				if isinstance(arg, (tuple, Quantity) + str_types):
					pars = {param: arg}
					if type(params) is dict:
						pars.update(params)
					args[i] = self.__get([self.__get_pam_scaled_name(param)], pars)

			# Note: param keyword cannot appear in params without keyword repetition in self.range.
			return sampler(*args)
		return pam_range

	################## Function iteration ##################################
	def ranges_iterator(self, ranges, params={}, masks=None, function=None, param_args=(), function_args=(), function_kwargs={}, nprocs=None, distributed=False, ranges_eval=None, progress=True):
		'''
		ranges_iterator(ranges, params={}, masks=None, function=None, param_args=(), function_args=(), function_kwargs={}, nprocs=None, distributed=False, ranges_eval=None, progress=True)

		This method is shorthand for:

		>>> RangesIterator(parameters=self, ranges=ranges, params=params, masks=masks, function=function, \
						function_kwargs=function_kwargs, nprocs=nprocs, ranges_eval=ranges_eval, progress=progress)

		The :class:`RangesIterator` object allows you to iterate over nested parameter
		ranges, which is useful when you want to sweep out a multidimensional parameter
		space; for example, when you want to make a 2D plot of some function. In
		some sense, this is a generalisation of the Python :func:`map` function.

		For more information, please refer to the :class:`RangesIterator` documentation.
		'''
		return RangesIterator(parameters=self, ranges=ranges, params=params, masks=masks, function=function, function_args=function_args, \
						function_kwargs=function_kwargs, nprocs=nprocs, distributed=distributed, ranges_eval=ranges_eval, progress=progress)

	################## CONVERT UTILITY #####################################
	def asvalue(self, **kwargs):
		'''
		asvalue(**kwargs)

		:param kwargs: A dictionary of parameter values
		:returns: Number (normally float, but could be complex, etc)

		A utility function to return what the united value of a parameter would
		be if it were overridden with *kwargs*. It is the logical partner
		of *asscaled(\*\*kwargs)*. For example:

		>>> p.asvalue(x=(1, 'nm'))
		1

		If no units are passed, then inout value is assumed to be non-dimensional,
		and units are lifted from the underlying parameter. For example:

		>>> p.x = (1,'ms')
		>>> p.asvalue(x=1)
		1000

		If multiple parameter values are specified, a dictionary of values is
		returned:
		>>> p.asvalue(x=1, y=2)
		{'x': 1000, 'y': 2}
		'''
		d = {}
		for param, value in kwargs.items():
			d[param] = self.convert(value, output=self.units(param), value=True)
		if len(d) == 1:
			return list(d.values())[0]
		return d

	def asscaled(self, **kwargs):
		'''
		asscaled(**kwargs)

		:param kwargs: A dictionary of parameter values
		:returns: Number (normally float, but could be complex, etc)

		A utility function to return what the scaled value of a parameter would
		be if it were overridden with *kwargs*. It is the logical partner
		of *asvalue(\*\*kwargs)*. For example:

		>>> p.asscaled(x=(1, 'm'))
		1

		Note that this is equivalent to :python:`p.convert((1, 'm'))`.
		If multiple parameter values are specified, a dictionary of values is
		returned:

		>>> p.asscaled(x=1, y=2)
		{'x': 1, 'y': 2}
		'''
		d = {}
		for param, value in kwargs.items():
			d[param] = self.convert(value)
		if len(d) == 1:
			return list(d.values())[0]
		return d

	def units(self, *params):
		'''
		units(*params)

		:param params: A sequence of parameters for which to extract the default units.
		:param type: tuple of str

		:returns: An dictionary of :class:`Units`, or, if only one param has been
		requested and not wrapped in a list, a single :class:`Units` object.

		This method returns the default units associated with a particular parameter.
		For example:

		>>> p << {'x': (1,'ms'), 'y': (1,'m')}
		>>> p.units('x')
		ms
		>>> p.units(['x'])
		{'x': ms}
		>>> p.units('x','y')
		{'x': ms, 'y': m}
		'''
		use_dict = False
		if len(params) == 1 and type(params[0]) == list:
			params = params[0]
			use_dict = True

		units = {}
		for param in params:
			units[param] = self.__parameters_spec.get(param, None)

		if len(params)==1 and not use_dict:
			return units[list(units.keys())[0]]
		return units

	def convert(self, quantity, input=None, output=None, value=True):
		'''
		convert(self,quantity,input=None, ouput=None, value=True)

		:param quantity: The quantity to be converted.
		:type quantity: :class:`Quantity`, `Quantity` tuple representation or any pythonic numeric type (including numpy arrays).
		:param input: The units of the inputed quantity (ignored if input type is :class:`Quantity`).
		:type input: :class:`None`, :class:`str`, or :class:`Units`
		:param output: The units to convert toward.
		:type output: :class:`None`, :class:`str`, or :class:`Units`
		:param value: Whether the function should return only the value (rather than the full :class:`Quantity` object).
		:type value: :class:`bool`

		:returns: Pythonic number if :python:`value` is :python:`True`, and :class:`Quantity` otherwise.
		'''

		if type(quantity) == list:
			return map(lambda q: self.convert(q, input, output, value), quantity)

		if type(quantity) == tuple and len(quantity) == 2:
			input = str(quantity[1])
			quantity = quantity[0]
		elif isinstance(quantity, Quantity):
			input = str(quantity.units)
			quantity = quantity.value

		if input is not None and output is not None:
			quantity /= self.__units(output).scale(input)

		elif input is not None:
			quantity /= self.__unit_scaling(self.__units(input))

		elif output is not None:
			quantity *= self.__unit_scaling(self.__units(output))

		if value:
			return quantity
		return Quantity(quantity, output, dispenser=self.__units)

	def optimise(self, param, *wrt, **params):
		'''
		optimise(param, *wrt, **params)

		This method returns either a function or string depending on whether
		the input :class:`param` consisted of more than a single parameter. For
		symbolic expressions, this can greatly speed up parameter retrieval. A
		similar mechanism is used internally to make parameter lookups fast. Additionally,
		it can pre-evaluate parameters that do not depend upon a parameter listed
		in `wrt`, subject to the parameter overrides of `params`. If `wrt` is not provided,
		only the functionalisation of the string representation of an expression is performed.

		:param param: Any parameter specification that is accepted by parameter retrieval.
		:param type: object
		:param wrt: Parameters for which all dependees should be preserved as variables.
		:type wrt: tuple
		:param params: Parameter overrides to use for the check as to whether a parameter
			is dependent on one of the parameters in `wrt`.
		:type params: dict

		:returns: A python function that can be passed to a Parameters instance for Parameters retrieval, or a string if the :class:`param` consisted of a single parameter name.
		:raises: ExpressionOptimisationError

		For example:

		>>> p.optimise('sin(x)*exp(-t)')
		< function with arguments x and t >

		>>> p.optimise('sin(x)*exp(-t)','t',x=1)
		<function with argument t, with x evaluated to 1>
		'''

		if param is None or isinstance(param, types.FunctionType) or isinstance(param, str_types) and self.__is_valid_param(param):
			return param

		elif isinstance(param, str_types) or type(param).__module__.startswith('sympy'):
			if len(wrt) > 0:
				subs = {}
				expr = sympy.S(param, locals=sympy.abc._clash)
				for symbol in expr.free_symbols:
					symbol = str(symbol)
					if symbol in self and self.is_constant(symbol, *wrt, **params):
						subs[symbol] = self.__get(str(symbol), params)
				expr = expr.subs(subs)
			else:
				expr = param
			return self.__sympy_to_function(expr)

		raise errors.ExpressionOptimisationError("No way to optimise parameter expression: %s ." % param)

	def is_resolvable(self, *args, **params):
		'''
		is_resolvable(*args, **params)

		:param args: Sequence of parameter names.
		:type args: tuple
		:param params: Dictionary of parameter value overrides.
		:type params: dict

		:returns: :python:`True` if each of the requested parameters can be
		successfully evaluated. :python:`False` otherwise.

		This method actually goes through
		the process of evaluating the parameter, so if you need its value, it is probably better to use a
		try-except block in your code around the usual parameter extraction code.

		Example:

		>>> p.x = 1
		>>> p.y = 'x*z'
		>>> p.is_resolvable('x')
		True
		>>> p.is_resolvable('x','y')
		False
		>>> p.is_resolvable('x','y',z=1)
		True
		'''
		try:
			self(*args, **params)
			return True
		except:
			return False

	def is_function(self, param, **params):
		'''
		is_function(param, **params)

		:param param: Name of parameter
		:type param: str
		:param params: Dictionary of parameter value overrides.
		:type params: dict

		:returns: :python:`True` if specified parameter is a function. :python:`False` otherwise.

		This method checks if a given parameter is a function, which usually
		implies it is dependent on other parameters. For example:

		>>> p.x = 3
		>>> p.is_function('x')
		False
		>>> p.is_function('x',x='3*t')
		True
		'''
		param_name = self.__get_pam_name(param)
		param_val = None

		if param_name in params:
			param_val = params[param]
		elif param_name in self.__parameters:
			param_val = self.__parameters[param]
		else:
			try:
				symbols = sympy.S(param, sympy.abc._clash).free_symbols
				for symbol in symbols:
					if str(symbol) != str(param):
						return True
			except:
				raise errors.ParameterInvalidError("This parameters instance has no parameter named '%s', and none was provided. Parameter may or may not be constant." % param)

		if isinstance(param_val, types.FunctionType) or isinstance(param_val, str_types) and isinstance(self.optimise(param_val), (types.FunctionType,) + str_types):
			return True
		return False

	def is_constant(self, param, *wrt, **params):
		'''
		is_constant(*args, **params)

		:param param: The param for which to test constancy.
		:type param: str
		:param wrt: A sequence of parameter names, with respect to which `param` should be constant.
		:type wrt: tuple
		:param params: Dictionary of parameter value overrides.
		:type params: dict

		:returns: :python:`True` if first listed parameter is independent of all subsequent parameters. :python:`False` otherwise.

		This method is useful for simplifying parameters in contexts where parameters
		are going to be often polled, by checking to see if they can be statically
		cached in your application. For example:

		>>> p.x = "3*t"
		>>> p.is_constant('x','t')
		False
		>>> p.is_constant('x','t',x=1)
		True
		'''
		if len(wrt) == 0:
			return True
		if param in wrt:
			return False

		param_name = self.__get_pam_name(param)
		param_val = None

		if param_name in params:
			param_val = params[param]
		elif param_name in self.__parameters:
			param_val = self.__parameters[param]
		else:
			try:
				symbols = sympy.S(param, sympy.abc._clash).free_symbols
				for symbol in symbols:
					if str(symbol) != str(param_val):
						if not self.is_constant(str(symbol), *wrt, **params):
							return False
				return True
			except errors.ParameterInvalidError as e:
				raise e
			except:
				raise errors.ParameterInvalidError("This parameters instance has no parameter named '%s', and none was provided. Parameter may or may not be constant." % param)

		if isinstance(param_val, str_types):
			param_val = self.optimise(param_val)
		else:
			param_val = self.__get_quantity(param_val)

		if isinstance(param_val, Quantity):
			return True
		elif isinstance(param_val, types.FunctionType):
			deps = self.__function_getargs(param_val)
			for dep in deps:
				dep = self.__get_pam_name(dep)
				if dep == param:
					continue
				if dep in wrt or not self.is_constant(dep, *wrt, **params):
					return False
			return True
		else:
			raise ValueError("Unable to check whether parameter '%s' of type '%s' is constant." % (param_val, type(param_val)))

	################## PLOTTING INTROSPECTION ##############################

	def plot(self, *params, **ranges):
		'''
		plot(*params, **ranges)

		:param params: A sequence of parameter expressions to plot.
		:type params: tuple
		:param ranges: A dictionary of parameter ranges and overrides.
		:type ranges: dict

		If Matplotlib is installed, this method provides a simple way to debug
		whether your parameter values are working as expected. The format of the
		ranges can be anything accepted by :func:`range`, but must only have one
		varying independent parameter.

		For example:

		>>> p.plot('x', x="sin(w*t)", w=2, t=(0,'2*3.142/w',50))

		The above example will generate a sinusoidal curve *x* vs. *t* plot
		at 50 equidistant intervals between 0 and the end of the first period.
		'''
		try:
			import matplotlib.pyplot as plt
		except:
			print(colour_text("Matplotlib is required for plotting features.", "RED", True))
			return

		if len(params) == 0:
			raise ValueError("You must specify a parameter to plot. i.e. plot('x',t=(0,10,10))")

		indep_count = 0
		for param, range in ranges.items():
				if type(range) == list or type(range) == tuple and len(range) > 2:
					indep_count += 1
					if indep_count > 1:
						raise ValueError("Plotting currently only supports one independent parameter.")
					indep = self.__get_pam_scaled_name(param)
					indep_units = self.units(indep)
		if indep_count == 0:
			raise ValueError("You must provide at least one range to act as independent parameter.")

		r = self.range(indep, *map(self.__get_pam_scaled_name, params), **ranges)

		plt.figure()
		for param in params:
			param_units = self.units(param)
			plt.plot(
					self.asvalue(**{indep: r[indep]}),
					self.asvalue(**{param: r[param]}),
					label=u"$%s\,(%s)$" % (self.__plot_subscripts(param), self.__plot_subscripts(unicode(param_units)) if param_units is not None else "units")
					)

		plt.xlabel(u"$%s\,(%s)$" % (self.__plot_subscripts(indep), self.__plot_subscripts(unicode(indep_units)) if indep_units is not None else 'units'))
		plt.legend(loc=0)

		plt.show()

	def __plot_subscripts(self, text):
		s = text.split('_')
		return '_{'.join(s) + '}' * (len(s) - 1)

	################## LOAD / SAVE PROFILES ################################

	@classmethod
	def load(cls, filename, **kwargs):
		'''
		load(cls, filename, **kwargs)

		:param filename: Filename from which to load parameters.
		:type filename: str
		:param kwargs: Dictionary of arguments to pass to :class:`Parameters` constructor.
		:type kwargs: dict

		:returns: A new :class:`Parameters` instance preloaded with the configuration contained in :python:`filename`.

		This is the method you should use to load a saved :class:`Parameters`
		configuration. For example:

		>>> p.load('params.py')

		The file being loaded should be a valid Python file, with one or more of
		the following variables available in the global namespace:
			- :python:`parameters` : a dictionary of parameter values with names as keys.
			- :python:`parameters_cache` : a dictionary of boolean values with names as keys (and where True indicates that the parameter should be cached, see :func:`cache`).
			- :python:`parameters_units` : a dictionary of parameter units with names as keys (only necessary to specify units for parameters which do not have a value attached to them, but for which it is useful to have default units)
			- :python:`dimension_scalings` : a dictionary of scalings with dimensions as keys (for valid scalings, see :func:`scaling`).
			- :python:`units_custom` : a list of dictionaries which contain the kwargs necessary to construct the custom unit (seel :func:`add_unit`).
		'''
		profile = imp.load_source('profile', filename)

		p = cls(**kwargs)

		p.scaling(**getattr(profile, "dimension_scalings", {}))

		for unit in getattr(profile, "units_custom", []):
			p + unit

		p << getattr(profile, "parameters", {})

		p.cache(**getattr(profile, "parameters_cache", {}))

		p & getattr(profile, "parameters_units", {})

		p.set_units_context(getattr(profile, "units_context", None))

		return p

	def __rshift__(self, other):

		if not isinstance(other, str_types):
			raise errors.ParametersException("The right shift operator is used to save the parameters to a file. The operand must be a filename.")

		self.__save__(other)
		return self

	def __save__(self, filename):
		f = open(filename, 'w')

		# Export unit context
		if self.units_context is not None:
			f.write('units_context = %s' % self.units_context)

		# Export dimension scalings
		f.write("dimension_scalings = {\n")
		for dimension, scaling in self.__scalings.items():
			f.write("\t\"%s\": (%s,\"%s\"),\n" % (dimension, scaling.value, scaling.units))
		f.write("}\n\n")

		# Export custom units
		f.write("units_custom = {\n")
		for unit in self.__units_custom:
			f.write("%s,\n" % unit)
		f.write("}\n\n")

		# Export parameters
		f.write("parameters = {\n")
		for pam, value in self.__parameters.items():
			f.write("\t\"%s\": (%s,\"%s\"),\n" % (pam, value.value, value.units))
		f.write("}\n\n")

		# Export parameters_cache
		f.write("parameters_cache = {\n")
		for pam in self.__cache_funcs:
			f.write("\t\"%s\": True,\n" % (pam))
		f.write("}\n\n")

		# Export parameters_units
		f.write("parameters_units = {\n")
		for pam, units in self.__parameters_spec.items():
			if pam not in self.__parameters:
				f.write("\t\"%s\": \"%s\",\n" % (pam, units))
		f.write("}\n\n")

		f.close()


class Bounds(object):
	'''
	Bounds(param, units, bounds, error=True, clip=False, inclusive=True)

	:param param: Name of param to which bound applies.
	:type param: str
	:param units: Units of parameter.
	:type units: str or :class:`Units`
	:param bounds: The bound specification. See :func:`Parameters.bounds`.
	:type bounds: List of bounds.
	:param error: A boolean flag named error.
	:type error: bool
	:param clip: A boolean flag named clip.
	:type clip: bool
	:param inclusive: A boolean flag named inclusive.
	:type inclusive: bool

	The :class:`Bounds` object is used by a :class:`Parameters` instance to store
	the properties of a parameter bound. This is the object type returned by
	:func:`Parameters.bounds`. The above parameters can be extracted using attributes
	(if b is an instance of Bounds):

	>>> b.param
	>>> b.units
	>>> ...
	'''

	def __init__(self, param, units, bounds, error=True, clip=False, inclusive=True):
		self.param = param
		self.units = units
		self.bounds = bounds
		self.error = error
		self.clip = clip
		self.inclusive = inclusive
