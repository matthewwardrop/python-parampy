from . import errors
from . import physical_constants
from .definitions import SIDispenser
from .iteration import RangesIterator
from .quantities import Quantity, SIQuantity
from .text import colour_text
from .units import Units, Unit
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
	Parameters(dispenser=None,default_scaled=True,constants=False)

	An object to manage the generation of scaled parameters; as well as
	handle the dependence of parameters upon one another. Parameters also
	supports adding bounds to parameters.

	Parameters
	----------
	dispenser : Should provide None or a custom unit dispenser. If None is
		provided, Parameters will instantiate an SIDispenser; which hosts
		the standard units relative to an SI basis.
	default_scaled : Whether the created Parameter object should by default
		return scaled (unitless) parameters.
	constants : Whether Parameters should import the physical constants when
		unit dispenser is subclass of SIDispenser.

	Examples
	--------

	Initialising a parameters object with the default settings
	>>> p = Parameters()

	## Parameters structure
		To see an overview of the parameter object; simply use:
		>>> p.show()

	## Parameter Extraction

		To retrieve a parameter 'x' from a Parameters instance, you use:
		>>> p('x')
		If default_scaled = True, then this will yield a scaled float. Otherwise
		this will return a Quantity object, which keeps track of units.
		To invert this, simply prepend a '_' to the parameter name.
		>>> p('_x')

		Provided that the parameter name does not clash with any methods
		of the Parameters object, you can use a shorthand for this:
		>>> p.x
		>>> p._x

		You can also temporarily override parameters while retrieving them,
		which is useful especially for functions of parameters. For example,
		if we want to extract 'y' when 'x'=2, without permanently changing
		the value of 'x', we could use:
		>>> p('y',x=2)

	## Parameter Setting

		Set a parameter value 'x' to 1 ms.
		>>> p(x=(1,'ms'))
		Parameter names must start with a letter or underscore; and may contain
		any number of letters, numbers, and underscores.

		When a unit is not specified, the parameter is assumed to be a
		scaled version of the parameter. If the unit has never been set,
		then a 'constant' unit is assumed; otherwise the older unit is used.
		>>> p(x=1)

		If the parameter name does not clash with a method of parameters,
		you can use the shorthand:
		>>> p.x = (1,'ms')

		You can specify the units of a parameter, without specifying its
		value:
		>>> p & {'x':'ms'}
		Note that if you do this when the parameter has already been set
		that the parameter will have its units changed, but its value
		will remain unchanged. Use this carefully.

		Set a parameter 'y' that depends on the current scaled value of
		'x' (if default_scale = True)
		>>> p(y=lambda x: x**2)
		OR
		>>> p(y= <function with argument 'x'>)

		If one wanted to use the united Quantity instead, they would use:
		>>> p(y=lambda _x: _x**2)
		Which would keep track of the units.

		We can set 'y' to have units of 'ms^2', even when using the scaled values.
		>>> p & {'y':'ms^2'}

		One can also set a parameter to *always* depend on another parameter.
		>>> p << {'y':lambda x: x**2}
		Now, whenever x is changed, y will change also.

		If you want 'x' to change with 'y', then you simply set 'y' as
		an invertable function of 'x'. If the argument 'y' is specified,
		the function should return the value of 'x'. e.g.
		>>> p << { 'y': lambda x,y=None: x**2 if y is None else math.sqrt(y) }

		Such relationships can be chained. For instance, we could set an invertible
		function for 'z' as a function of 'x' and 'y'. Note that when an invertible
		function is inverted, it should return a tuple of variables in the
		same order as the function declaration.
		>>> p << { 'z': lambda x,y,z=None: x**2+y if z is None else (1,2) }

		You can also use the shorthand:
		>>> p.z = lambda x,y,z=None: x**2+y if z is None else (1,2)
		Note that setting attributes in this way keeps the functional dependence.

		We can then update z in the normal way:
		>>> p(z=1)
		This results in Parameters trying to resolve y=2 => x= sqrt(2) and
		x=1. This will return a ValueError with a description of the problem.
		However, this allows one to have an intricate variable structure.

		If a parameter has a functional dependence, but is not invertible,
		and it is updated as above, an error will be raised. However, if
		the is being specified only as an override, it is maintained, but
		may result in the parameters being inconsistent.

		To force parameters to be overridden, whether or not the parameter is
		a function, use the left shift operator:
		>>> p << {'z': (1,'ms')}

	## Removing Parameters

		To remove a parameter, simply use the forget method:
		>>> p.forget('x','y',...)

	## Parameter Units and Scaling

		You can add your own custom units by adding them directly to the
		unit dispenser used to set up the Parameters instance; or by
		adding them to the parameters object like:
		>>> p.unit_add(names='testunit',abbr='TU',rel=1e7,prefixable=False,dimensions={'mass':1,'length':1})
		For a description of what the various keys mean, see the documentation
		for Unit.

		It is sometimes useful to have a scaled representation of the
		parameters that is different from the standard SI values. You can set
		a new basis unit for any dimension: i.e.  For the below, all scaled 'length'
		parameters will be scaled by 0.5 compared to the former basis of (1,'m').
		>>> p.scaling(length=(2,'m'),...)

		You can retrieve the current scaling for any dimension using:
		>>> p.scaling('length','time',...)

		To view the cumulative scaling for any unit, you can use:
		>>> p.unit_scaling('J','kg',...)

	## Unit Conversion

		It is useful to have a mechanism that scales all physical units
		in the same way as your parameters. Parameters instances allow
		you to convert physical units to and from the internal representation
		used by the Parameters object.

		For example:
		>>> p.convert( 1.0 , input='ms')
		converts 1 ms to the internal scaled representation of that parameter.
		Whereas:
		>>> p.convert( 1.0 , output='ms')
		converts a scaled parameter with dimension of 'time' to a Quantity
		with units of 'ms'.
		>>> p.convert( 1.0 , output='ms', value=True)
		converts a scaled parameter with dimension of time to number corresponding
		to the value of Quantity with units of 'ms'.

	## Parameter Bounding

		Sometimes it is necessary to be sure that a parameter is within
		certain bounds. Parameter objects can ensure this for you, with
		minimal overhead in performance. To set a bound you can use:
		>>> p['x'] = (0,100)
		If one of the extremum values is None, it is set to -infinity or
		+infinity, depending upon whether it is the upper or lower bound.
		If a disjointed bound is necessary, you can use:
		>>> p['x'] = [ (None,10), (15,None) ]

		If you need more power over the bounds, you can use the
		set_bounds method. In addition to the bounds described above, it
		accepts three keyword arguments: error, clip and inclusive.
			error (True) : This keyword determines whether a parameter
				found to be outside this bound should trigger an error;
				or if clip is True, whether a warning should be generated.
			clip (False) : If true, the parameter will be clipped to
				the nearest bound edge (assumes inclusive is True).
				If error is true, a warning will be generated.
			inclusive (True) : Whether the upper and lower bounds are
				to be included in the range.
		>>> p.set_bounds( {'x':(0,100)}, error=True, clip=True, inclusive=True )

	## Parameter Ranges

		It is often the case that one would like to iterate over various
		parameter ranges, or to investigate how one parameter changes
		relative to another. The Parameters object makes this easy with
		the 'range' method. The range method has similar syntax to the
		parameter extraction method; but is kept separate for clarity and
		efficiency.

		>>> p << {'y':lamdba x:x**2}
		>>> p.range( 'y', x = [0,1,2,3] )
		This will return: [0,1.,4.,9.].

		Arrays may be input as lists or numpy ndarrays; and returned arrays
		are typically numpy arrays.

		The values for parameter overrides can also be provided in a more
		abstract notation; such that the range will be generated when the
		function is called. Parameters accepts ranges in the following forms:
		 - (<start>,<stop>,<count>) ; which will generate a linear array
		   from <start> to <stop> with <count> values.
		 - (<start>,<stop>,<count>,<sampler>) ; which is as above, but where
		   the <sampler> is expected to generate the array. <sampler> can
		   be a string (either 'linear','log','invlog' for linear, logarithmic,
		   or inverse logarithmic distributions respectively); or a function
		   which takes arguments <start>,<stop>,<count> .

		>>> p.range( 'y', x = (0,10,2) )
		returns: [0.,100.]

		It is also possible to determine multiple parameters at once.
		>>> p.range( 'x', 'y', x=(0,10,2) )
		returns: {'x':[0.,10.], 'y':[0.,100.]}

		If multiple overrides are provided, they must either be constant
		or have the same length.
		>>> p.range( 'x', x=(0,10,2), z=1 )
		is OKAY
		>>> p.range( 'x', x=(0,10,2), z=[1,2,3] )
		is NOT okay.

	## Physical Constants

		To make life easier, Parameters instances also broadcasts the physical
		constants defined in "physical_constants.py" when using an SIDispenser
		if constants is set to 'True'. These constants function just as
		any other parameter, and can be overriden. For example:
		>>> p.c_hbar

	## Loading and Saving

		To load a parameter set into a Parameters instance, use the classmethod:
		>>> p = Parameters.load( "filename.py" )
		Note that parameters defined as functions will be imported as functions.

		To see the format of a parameters instance, or to save your existing parameters,
		use:
		>>> p >> "filename.py"
		Note that functional parameters will only be saved as static values.

	## Temporary changes

		Parameters objects support Python's "with" syntax. Upon exiting a "with"
		environment, any changes made will be reset to before entering the environment.

		>>> with p:
		>>> 	p(x=1)
		>>> p('x') # Returns value of x before entering the with environment.
	"""

	def __init__(self, dispenser=None, default_scaled=True, constants=False):
		self.__parameters_spec = {}
		self.__parameters = {}
		self.__parameters_bounds = None
		self.__scalings = {}
		self.__units = dispenser if dispenser is not None else SIDispenser()
		self.__units_custom = []
		self.__default_scaled = default_scaled

		self.__cache_deps = {}
		self.__cache_sups = {}
		self.__cache_scaled = {}
		self.__cache_funcs = {}

		self.__scaling_cache = {}

		if constants and isinstance(self.__units, SIDispenser):
			self(**physical_constants.constants)

	############## PARAMETER OBJECT CONFIGURATION ##############################
	def __add__(self, other):
		self.unit_add(other)
		return self

	def unit_add(self, *args, **kwargs):
		'''
		This adds a unit to a custom UnitDispenser. See UnitDispenser.add for more info.
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

	def scaling(self, *args, **kwargs):
		'''
		Sets the scaling of a particular dimension. For example:
		p.scaling(length='m')
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
		Sets the scaling of a particular unit. Care should be taken as this could
		result in inconsistent scalings.
		'''
		r = {}
		for param in params:
			r[param] = self.__unit_scaling(param)
		if len(params) == 1:
			return r[params[0]]
		return r

	def __get_unit(self, unit):

		if isinstance(unit, str):
			return self.__units(unit)

		elif isinstance(unit, Units):
			return unit

		raise errors.UnitInvalidError("No coercion for %s to Units." % unit)

	################## ENABLE USE WITH 'with' ####################################

	def __enter__(self):
		self.__context_save = {
			'parameters_spec': copy.copy(self.__parameters_spec),
			'parameters': copy.copy(self.__parameters),
			'parameters_bounds': copy.copy(self.__parameters_bounds),
			'scalings': copy.copy(self.__scalings),
			'units': copy.copy(self.__units),
			'units_custom': copy.copy(self.__units_custom),
			'default_scaled': copy.copy(self.__default_scaled),
		}

	def __exit__(self, type, value, traceback):

		# Restore context
		self.__parameters_spec = self.__context_save['parameters_spec']
		self.__parameters = self.__context_save['parameters']
		self.__parameters_bounds = self.__context_save['parameters_bounds']
		self.__scalings = self.__context_save['scalings']
		self.__units = self.__context_save['units']
		self.__units_custom = self.__context_save['units_custom']
		self.__default_scaled = self.__context_save['default_scaled']

		# Remove context
		del self.__context_save

		# Clear cache
		self.__cache_deps = {}
		self.__cache_sups = {}
		self.__cache_scaled = {}

		self.__scaling_cache = {}

	############# PARAMETER RESOLUTION #########################################
	def __get_pam_name(self, param):
		if isinstance(param, str):
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
			if isinstance(value, types.FunctionType):
				self.__cache_deps[param] = inspect.getargspec(value).args
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

	def __get(self, args, kwargs={}):
		'''
		Retrieve the parameters specified in args, with temporary values overriding
		defaults as in kwargs. Parameters are returned as Quantity's.
		'''
		self.__process_override(kwargs)

		if len(args) == 1:
			result = self.__get_param(args[0], kwargs)
			if self.__parameters_bounds is not None:
				kwargs[args[0]] = result
				self.__forward_check_bounds(args, kwargs)
			return result

		results = self.__get_params(args, kwargs)
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
			if isinstance(arg, str):
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

	def __get_params(self, args, kwargs={}):
		rv = {}
		for arg in args:
			rv[self.__get_pam_name(arg)] = self.__get_param(arg, kwargs)
		return rv

	def __get_param(self, arg, kwargs={}):
		'''
		Returns the value of a param `arg` with its dependent variables overriden
		as in `kwargs`. If `arg` is instead a function, a string, or a Quantity, action is taken to
		evaluate it where possible.
		'''
		if arg == '_':
			raise ValueError()
		pam_name = self.__get_pam_name(arg)

		# If the parameter is actually a function or otherwise not directly in the dictionary of stored parameters
		if not isinstance(arg, str) or (pam_name not in kwargs and pam_name not in self.__parameters):
			return self.__eval(arg, kwargs)
		else:
			scaled = self.__default_scaled
			if arg[:1] == "_":  # .startswith("_"):
				arg = arg[1:]
				scaled = not scaled

			# If the parameter is temporarily overridden, return the override value
			if arg in kwargs:
				return self.__get_quantity(kwargs[arg], param=arg, scaled=scaled)

			# If the parameter is a function, evaluate it with local parameter values (except where overridden in kwargs)
			elif isinstance(self.__parameters[arg], types.FunctionType):
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

	def __process_override(self, kwargs, restrict=None, abort_noninvertable=False):
		'''
		Process kwargs and make sure that if one of the provided overrides
		corresponds to an invertable function, that the affected variables are also included
		as overrides also. An warning is thrown if these variables are specified also.
		'''

		if len(kwargs) == 0:
			return

		if restrict is None:
			restrict = kwargs.keys()

		if len(restrict) == 0:
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
				raise ValueError("Parameter type is autodetected. Do not use '_' to switch between scaled and unitted parameters.")
			val = kwargs[pam]
			if type(val) is str:
				val = self.__get_function(val)
				kwargs[pam] = val
			if type(val) is tuple and type(val[0]) is types.FunctionType:
				val = val[0]
			if type(val) is tuple and type(val[0]) is str:
				val = self.__get_function(val[0])
			if type(val) is types.FunctionType:
				pam = self.__get_pam_name(pam)
				deps = [self.__get_pam_name(dep) for dep in inspect.getargspec(val).args]
				dependencies[pam] = set(deps)

		pam_order = pam_ordering(dependencies)
		# print pam_order
		# First evaluate functions to avoid errors later on
		for pam in pam_order:
			if pam in kwargs:
				val = kwargs[pam]
				new = kwargs.copy()
				del new[pam]
				kwargs[pam] = self.__get_param(val, new)

		# Now, ratify these changes through the parameter sets to ensure
		# that the effects of these overrides is properly implemented
		new = {}
		for pam in restrict:
			if type(self.__parameters.get(pam)) is types.FunctionType:
				try:
					vals = self.__eval_function(pam, kwargs)
					for key in vals:
						if key in kwargs and vals[key] != kwargs[key] or key in new and vals[key] != new[key]:
							raise errors.ParameterOverSpecifiedError("Parameter %s is overspecified, with contradictory values. (%s vs. %s)" % (key,vals[key],kwargs[key] if key in kwargs else new[key]) )
					new.update(vals)
				except errors.ParameterNotInvertableError as e:
					if abort_noninvertable:
						raise e
					warnings.warn(errors.ParameterInconsistentWarning("Parameters are probably inconsistent as %s was overridden, but is not invertable, and so the underlying variables (%s) have not been updated." % (pam, ','.join(inspect.getargspec(self.__parameters.get(pam)).args))))

		if len(new) != 0:
			kwargs.update(new)
			self.__process_override(kwargs, restrict=new.keys())

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

		# Check if we are allowed to continue
		if param in kwargs and param not in deps and "_" + param not in deps:
			raise errors.ParameterNotInvertableError("Configuration requiring the inverting of a non-invertable map for %s." % param)

		arguments = []
		for arg in deps:

			if arg in (param, "_%s" % param) and param not in kwargs:
				continue

			arguments.append(self.__get_param(arg, kwargs))

		cached = self.__cache_func_handler(param, params=arguments)
		if cached is not None:
			return {param: cached}
		else:
			r = f(*arguments)
			if not isinstance(r, (list,tuple)):
				r = [r]

			# If we are not performing the inverse operation
			if param not in kwargs:
				value = self.__get_quantity(r[0], param=param)
				self.__cache_func_handler(param, value=value, params=arguments)
				return {param: value}

		# Deal with the inverse operation case
		inverse = {}

		for i, arg in enumerate(deps):
			pam = self.__get_pam_name(arg)

			if pam not in (param, "_%s" % param):
				inverse[pam] = self.__get_quantity(r[i], param=pam)

		return inverse

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
		Allow enabling and disabling of cache for parameter functions.
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

	def __eval(self, arg, kwargs={}):

		t = type(arg)

		if t == tuple:
			return self.__get_quantity((self.__eval(arg[0], kwargs), arg[1]), scaled=self.__default_scaled)

		elif isinstance(arg, Quantity):
			return self.__get_quantity(arg, scaled=self.__default_scaled)

		elif t == types.FunctionType:
			deps = inspect.getargspec(arg)[0]
			params = self.__get_params(deps, kwargs)
			args = [val for val in [params[self.__get_pam_name(x)] for x in deps]]  # Done separately to avoid memory leak when cythoned.
			return arg(*args)

		elif isinstance(arg, str) or arg.__class__.__module__.startswith('sympy'):
			try:
				if isinstance(arg, str):
					if arg in self.__parameters:
						return self.__get_param(arg, kwargs)

					arg = sympy.S(arg, sympy.abc._clash)
					fs = list(arg.free_symbols)
					if len(fs) == 1 and str(arg) == str(fs[0]):
						raise errors.ParameterInvalidError("There is no parameter, and no interpretation, of '%s' which is recognised by Parameters." % arg)
				params = {}
				for sym in arg.free_symbols:
					param = self.__get_param(str(sym), kwargs)
					if isinstance(param, Quantity):
						raise errors.SymbolicEvaluationError("Symbolic expressions can only be evaluated when using scaled parameters. Attempted to use '%s' in '%s', which would yield a united quantity." % (sym, arg))
					params[str(sym)] = self.__get_param(str(sym), kwargs)
				result = arg.subs(params).evalf()
				if result.as_real_imag()[1] != 0:
					return complex(result)
				return float(result)
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
			if isinstance(val, (types.FunctionType, str)):
				self.__parameters[param] = self.__check_function(param, self.__get_function(val))
				self.__spec({param: self.__get_unit('')})
			elif isinstance(val, (list, tuple)) and isinstance(val[0], (types.FunctionType, str)):
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

		self.__process_override(kwargs, abort_noninvertable=True)

		for param, value in kwargs.items():
			if param not in self.__parameters or not isinstance(self.__parameters.get(param), types.FunctionType):
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
		for param in params:
			self.__remove(param)
		return self

	def __lshift__(self, other):

		if not isinstance(other, dict):
			raise errors.ParametersException("The left shift operator sets parameter values without interpretation; such as functions. It accepts a dictionary of parameter values.")

		self.__set(other)
		return self

	def __sympy_to_function(self, expr):
		try:
			expr = sympy.S(expr, locals=sympy.abc._clash)
			syms = list(expr.free_symbols)
			f = sympy.utilities.lambdify(syms, expr, dummify=False)
			return f
		except:
			raise errors.SymbolicEvaluationError('String \'%s\' is not a valid symbolic expression.' % (expr))

	def __get_function(self, expr):
		if isinstance(expr, types.FunctionType):
			return expr
		return self.__sympy_to_function(expr)

	def __check_function(self, param, f, forbidden=None):

		args = inspect.getargspec(f).args

		while param in args:
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

	def __setattr__(self, attr, value):
		if attr.startswith('__') or attr.startswith('_Parameters'):
			return super(Parameters, self).__setattr__(attr, value)
		return self.__set({attr: value})

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

		print self.__table(parameters)

	def __repr__(self):
		return "< Parameters with %d definitions >" % len(self.__parameters)

	def __dir__(self):
		res = dir(type(self)) + list(self.__dict__.keys())
		res.extend(self.__parameters.keys())
		return res

	def __getattr__(self, name):
		if name[:2] == "__" or name[:11] == "_Parameters":
			raise AttributeError
		return self.__get_param(name)

	################## PARAMETER BOUNDS ####################################

	def set_bounds(self, bounds_dict, error=True, clip=False, inclusive=True):
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

	def __getitem__(self, key):
		try:
			return self.__parameters_bounds[key].bounds
		except:
			return None

	def __setitem__(self, key, value):
		self.set_bounds({key: value})

	################## RANGE UTILITY #######################################

	def range(self, *args, **ranges):

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

		for i in range(count):
			d = {}
			d.update(static)
			for key in lists:
				d[key] = lists[key][i]

			argvs = self.__get(args, d)

			if len(args) == 1:
				if values is None:
					values = []
				values.append(argvs)
			else:
				if values is None:
					values = {}
				for arg in args:
					if arg not in values:
						values[arg] = []
					values[arg].append(argvs[arg])

		return values

	def __range_sampler(self, sampler):
		if isinstance(sampler, str):
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
				if isinstance(arg, (tuple, str, Quantity)):
					pars = {param: arg}
					if type(params) is dict:
						pars.update(params)
					args[i] = self.__get([self.__get_pam_scaled_name(param)], pars)

			# Note: param keyword cannot appear in params without keyword repetition in self.range.
			return sampler(*args)
		return pam_range

	################## Function iteration ##################################
	def ranges_iterator(self, ranges):
		return RangesIterator(ranges=ranges, parameters=self)

	################## CONVERT UTILITY #####################################
	def asvalue(self, **kwargs):
		d = {}
		for param, value in kwargs.items():
			d[param] = self.convert(value, output=self.units(param), value=True)
		if len(d) == 1:
			return d.values()[0]
		return d

	def asscaled(self, **kwargs):
		d = {}
		for param, value in kwargs.items():
			d[param] = self.convert(value)
		if len(d) == 1:
			return d.values()[0]
		return d

	def units(self, *params):
		l = list(self.__parameters_spec.get(param, None) for param in params)
		if len(params) == 1:
			return l[0]
		return l

	def convert(self, quantity, input=None, output=None, value=True):

		if isinstance(quantity, Quantity):
			input = str(quantity.units)
			quantity = quantity.value

		if input is None and output is None:
			return quantity

		elif output is None:
			return quantity / self.__unit_scaling(self.__units(input))

		elif input is None:
			q = self.__get_quantity(quantity, unit=output)

		else:
			q = Quantity(quantity, input, dispenser=self.__units)(output)

		if value:
			return q.value
		return q

	def optimise(self, param):
		'''
		Optimise the parameter query operator for fast operation times.
		'''

		if param is None or isinstance(param, types.FunctionType) or isinstance(param, str) and self.__is_valid_param(param):
			return param

		elif isinstance(param, str) or type(param).__module__.startswith('sympy'):
			return self.__sympy_to_function(param)

		raise errors.ExpressionOptimisationError("No way to optimise parameter expression: %s ." % param)

	def is_resolvable(self, *args, **params):
		'''
		Returns True if the parameter can be successfully evaluated, and False otherwise. This method actually goes through
		the process of evaluating the parameter, so if you need its value, it is probably better to use a
		try-except block in your code around the usual parameter extraction code.
		'''
		try:
			self(*args, **params)
			return True
		except:
			return False

	def is_function(self, param, **params):
		'''
		Returns True if the parameter depends upon other parameters; and False otherwise. This method accepts
		also accepts strings (as representations of mathematical expressions). Note that this method does NOT
		accept tuples.
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

		if isinstance(param_val, types.FunctionType) or isinstance(param_val, str) and isinstance(self.optimise(param_val), (types.FunctionType, str)):
			return True
		return False

	def is_constant(self, *args, **params):
		'''
		Returns True if the first parameter provided in the args list is independent of all subsequent ones, when evaluated using `params`. Returns False otherwise. Note
		that this method does not accept parameters as part of a tuple.
		'''
		param, wrt = None, []
		if len(args) == 0:
			raise ValueError("A parameter must be specified. Additional parameters may be passed, in which case this function returns true iff the parameter is constant with respect to to all additional parameters.")
		if len(args) == 1:
			param = args[0]
		elif len(args) >= 2:
			param = args[0]
			wrt = args[1:]

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

		if isinstance(param_val, str):
			param_val = self.optimise(param_val)
		else:
			param_val = self.__get_quantity(param_val)

		if isinstance(param_val, Quantity):
			return True
		elif isinstance(param_val, types.FunctionType):
			deps = inspect.getargspec(param_val).args
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
		try:
			import matplotlib.pyplot as plt
		except:
			print colour_text("Matplotlib is required for plotting features.", "RED", True)

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
					label="$%s\,(%s)$" % (self.__plot_subscripts(param), self.__plot_subscripts(str(param_units)) if param_units is not None else "units")
					)

		plt.xlabel("$%s\,(%s)$" % (self.__plot_subscripts(indep), self.__plot_subscripts(str(indep_units)) if indep_units is not None else 'units'))
		plt.legend(loc=0)

		plt.show()

	def __plot_subscripts(self, text):
		text = text.replace('{mu}', '{\mu}')
		s = text.split('_')
		return '_{'.join(s) + '}' * (len(s) - 1)

	################## LOAD / SAVE PROFILES ################################

	@classmethod
	def load(cls, filename, **kwargs):
		profile = imp.load_source('profile', filename)

		p = cls(**kwargs)

		p.scaling(**getattr(profile, "dimension_scalings", {}))

		for unit in getattr(profile, "units_custom", []):
			p + unit

		p << getattr(profile, "parameters", {})

		p.cache(**getattr(profile, "parameters_cache", {}))

		p & getattr(profile, "parameters_units", {})

		return p

	def __rshift__(self, other):

		if not isinstance(other, str):
			raise errors.ParametersException("The right shift operator is used to save the parameters to a file. The operand must be a filename.")

		self.__save__(other)
		return self

	def __save__(self, filename):
		f = open(filename, 'w')

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

	def __init__(self, param, units, bounds, error=True, clip=False, inclusive=True):
		self.param = param
		self.units = units
		self.bounds = bounds
		self.error = error
		self.clip = clip
		self.inclusive = inclusive
