import types,inspect,warnings,imp,re

import numpy as np
import sympy

from .definitions import SIDispenser
from .quantities import Quantity,SIQuantity
from .units import Units,Unit
from . import physical_constants
from .text import colour_text
from . import errors

class Parameters(object):
	"""
	Parameters(dispenser=None,default_scaled=True,constants=False)
	
	An object to manage the generation of scaled parameters; as well as 
	handle the dependence of parameters upon one another.
	
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
		
		To remove a parameter, simply use the subtraction operator:
		>>> p - 'x'
	
	## Parameter Units and Scaling
		
		You can add your own custom units by adding them directly to the
		unit dispenser used to set up the Parameters instance; or by 
		adding them to the parameters object like:
		>>> p + {'names':'testunit','abbr':'TU','rel':1e7,'length':1,'mass':1,'prefixable':False}
		For a description of what the various keys mean, see the documentation
		for Unit.
		
		It is sometimes useful to have a scaled representation of the 
		parameters that is different from the standard SI values. You can set
		a new basis unit for any dimension: i.e.  For the below, all scaled 'length'
		parameters will be scaled by 0.5 compared to the former basis of (1,'m').
		>>> p * {'length':(2,'m')}
		
		You can also change the scaling for particular combinations of dimensions
		on top of the basis scalings. The below will cause all "acceleration" 
		parameters to be multiplied by 2.5 in their scaled forms.
		>>> p * ({'length':1,'time':-2},2.5)
	
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
	
	## Physical Constants
		
		To make life easier, Parameters instances also broadcasts the physical
		constants defined in "physical_constants.py" when using an SIDispenser
		if constants is set to 'True'. These constants function just as 
		any other parameter, and can be overriden. For example:
		>>> p.hbar
	
	## Loading and Saving
		
		To load a parameter set into a Parameters instance, use the classmethod:
		>>> p = Parameters.load( "filename.py" )
		To see the format of a parameters instance, or to save your existing parameters,
		use:
		>>> p >> "filename.py"
	
	"""
	# Parameters are retrieved as:
	# pams.<var> returns stored value or function
	# pams.<var>(<pams>)
	
	def __init__(self,dispenser=None,default_scaled=True,constants=False):
		self.__parameters_spec = {}
		self.__parameters = {}
		self.__parameters_bounds = {}
		self.__scalings = {}
		self.__unit_scalings = []
		self.__units = dispenser if dispenser is not None else SIDispenser()
		self.__units_custom = []
		self.__default_scaled = default_scaled
		
		self.__scaling_cache = {}
		
		if constants and isinstance(self.__units,SIDispenser):
			self(**physical_constants.constants)
	
	############## PARAMETER OBJECT CONFIGURATION ##############################
	def __add__(self,other):
		self.__unit_add(other)
		return self
		
	def __unit_add(self,other):
		'''
		This adds a unit to a custom UnitDispenser. See UnitDispenser.add for more info.
		'''
		if isinstance(other,dict):
			other = Unit(**other)
		if isinstance(other, Unit):
			self.__units.add(other)
			self.__units_custom.append(other)
	
	def __mul__(self,other):
		self.__scaling_set(other)
		return self
		
	def __scaling_set(self,kwargs):
		self.__scaling_cache = {}
		
		# If kwargs is dict, then add a new dimension scaling
		if isinstance(kwargs,dict):
			for arg in kwargs:
				if arg in self.__units.dimensions:
					scale = self.__get_quantity(kwargs[arg],param=arg)
					if scale.units.dimensions == {arg:1}:
						self.__scalings[arg] = scale
					else:
						raise errors.ScalingUnitInvalidError( "Dimension of scaling (%s) is wrong for %s." % (scale.units,arg) )
				else:
					raise errors.ScalingDimensionInvalidError("Invalid scaling dimension %s." % arg)
		
		# Otherwise, add a new unit scaling
		elif isinstance(kwargs,(list,tuple)) and len(kwargs)==2:
			self.__unit_scalings.append(kwargs)
		
		else:
			raise errors.ScalingValueError( "Cannot set scaling with %s." % kwargs )
	
	def __get_unit(self,unit):
		
		if isinstance(unit,str):
			return self.__units(unit)
		
		elif isinstance(unit,Units):
			return unit
		
		raise errors.UnitInvalidError( "No coercion for %s to Units." % unit )
			
	############# PARAMETER RETRIEVAL ##########################################
	
	def __get(self,*args,**kwargs):
		'''
		Retrieve the parameters specified in args, with temporary values overriding
		defaults as in kwargs. Parameters are returned as Quantity's.
		'''
		
		self.__process_override(kwargs)
		
		return self.__get_params(*args,**kwargs)
	
	def __get_params(self,*args,**kwargs):
		
		if len(args) == 1:
			return self.__get_param(args[0],**kwargs)
		
		rv = {}
		for arg in args:
			rv[self.__get_pam_name(arg)] = self.__get_param(arg,**kwargs)
		
		return rv
		
	
	def __get_param(self,arg,**kwargs):
		'''
		Returns the value of a param `arg` with its dependent variables overriden
		as in `kwargs`.
		'''
		
		# If the parameter is actually a function
		if not isinstance(arg,str) or (self.__get_pam_name(arg) not in kwargs and self.__get_pam_name(arg) not in self.__parameters):
			return self.__eval(arg,**kwargs)
			
		else:
			scaled = self.__default_scaled
			if arg[:1] == "_": #.startswith("_"):
				arg = arg[1:]
				scaled=not scaled
			
			# If the parameter is temporarily overridden, return the override value
			if arg in kwargs:
				return self.__get_quantity(kwargs[arg],param=arg,scaled=scaled)
		
			# If the parameter is a function, evaluate it with local parameter values (except where overridden in kwargs)
			elif isinstance(self.__parameters[arg],types.FunctionType):
				return self.__get_quantity(self.__eval_function(arg,**kwargs)[arg],param=arg,scaled=scaled)
		
			# Otherwise, return the value currently stored in the parameters
			else:
				return self.__get_quantity(self.__parameters[arg],param=arg,scaled=scaled)
	
	def __get_pam_name(self,param):
		if isinstance(param,str):
			if param[:1] == "_":
				return param[1:]
			return param
		return param

	def __get_pam_scaled_name(self,param):
		param = self.__get_pam_name(param)
		if self.__default_scaled:
			return param
		return "_%s"%param

	def __get_pam_united_name(self,param):
		param = self.__get_pam_name(param)
		if not self.__default_scaled:
			return param
		return "_%s"%param
	
	def __process_override(self,kwargs,restrict=None,abort_noninvertable=False):
		'''
		Process kwargs and make sure that if one of the provided overrides 
		corresponds to an invertable function, that the affected variables are also included
		as overrides also. An warning is thrown if these variables are specified also.
		'''
		
		if restrict is None:
			restrict = kwargs.keys()
		
		if len(restrict) == 0:
			return
		
		# Check to see whether override arguments are functions; and if so
		# first evaluate them.
		for pam,val in list(kwargs.items()):
			if pam in restrict:
				if isinstance(val,str):
					val = self.__get_function(val)
				if isinstance(val,types.FunctionType):
					new = kwargs.copy()
					del new[pam]
					kwargs[pam] = self.__get_param(val,**new)
		
		# Now, ratify these changes through the parameter sets to ensure
		# that the effects of these overrides is properly implemented
		new = {}
		for pam,val in kwargs.items():
			if pam in restrict:
				if isinstance(self.__parameters.get(pam),types.FunctionType):
					try:
						vals = self.__eval_function(pam,**kwargs)
						for key in vals:
							if key in kwargs and vals[key] != kwargs[key] or key in new and vals[key] != new[key]:
								raise errors.ParameterOverSpecifiedError("Parameter %s is overspecified, with contradictory values." % key)
						new.update(vals)
					except errors.ParameterNotInvertableError, e:
						if abort_noninvertable:
							raise e
						warnings.warn(errors.ParameterInconsistentWarning("Parameters are probably inconsistent as %s was overridden, but is not invertable, and so the underlying variables (%s) have not been updated." % (pam, ','.join(inspect.getargspec(self.__parameters.get(pam)).args))))
		
		kwargs.update(new)
		self.__process_override(kwargs,restrict=new.keys())
	
	def __eval_function(self,param,**kwargs):
		'''
		Returns a dictionary of parameter values. If the param variable itself is provided,
		then the function has its inverse operator evaluated. Functions must be of the form:
		def f(<pam>,<pam>,<param>=None)
		If <pam> is prefixed with a "_", then the scaled version of the parameter is sent through
		instead of the Quantity version.
		'''
		
		f = self.__parameters.get(param)
		
		# Check if we are allowed to continue
		if param in kwargs and param not in inspect.getargspec(f)[0] and "_"+param not in inspect.getargspec(f)[0]:
			raise errors.ParameterNotInvertableError( "Configuration requiring the inverting of a non-invertable map for %s."%param )
		
		arguments = []
		for arg in inspect.getargspec(f)[0]:
			
			if arg in (param,"_%s"%param) and param not in kwargs:
				continue
			
			arguments.append(self.__get_param(arg,**kwargs))
		
		r = f(*arguments)
		if not isinstance(r,list):
			r = [r]
		
		# If we are not performing the inverse operation
		if param not in kwargs:
			return {param: self.__get_quantity(r[0],param=param)}
		
		# Deal with the inverse operation case
		inverse = {}
		
		for i,arg in enumerate(inspect.getargspec(f)[0]):
			if arg[:1] == '_': #.startswith('_'):
				pam = arg[1:]
			else:
				pam = arg
			
			if pam != param and pam != "_%s" % param:
				inverse[self.__get_pam_name(arg)] = self.__get_quantity(r[i],param=pam)
		
		return inverse
	
	def __get_quantity(self, value, param=None, unit=None, scaled=False):
		'''
		Return a Quantity or scaled float associated with the value provided
		and the dimensions of param.
		'''
		
		q = None
		
		# If tuple of (value,unit) is presented
		if isinstance(value,(tuple,list)):
			if len(value) != 2:
				raise errors.QuantityCoercionError("Tuple specifications of quantities must be of form (<value>,<unit>). Was provided with %s ."%str(value))
			else:
				q = Quantity(*value,dispenser=self.__units)
		
		elif isinstance(value, Quantity):
			q = value
		
		elif isinstance(value,types.FunctionType):
			q = value
		
		else:
			if unit is None and param is None:
				unit = self.__get_unit('')
			elif unit is not None:
				unit = self.__get_unit(unit)
			else:
				unit = self.__get_unit(''  if self.__parameters_spec.get(param) is None else self.__parameters_spec.get(param) )
			q = Quantity(value*self.__unit_scaling(unit), unit,dispenser=self.__units)
		
		if isinstance(q, Quantity) and param is not None and param in self.__parameters_bounds:
			q = self.__parameters_bounds[param].check(q)
			
		if not scaled:
			return q
		
		return q.value/self.__unit_scaling(q.units)

	
	def __eval(self,arg,**kwargs):
		if isinstance(arg,types.FunctionType):
			params = self.__get_params(*inspect.getargspec(arg)[0],**kwargs)
			if not isinstance(params,dict):
				params = {self.__get_pam_name(inspect.getargspec(arg)[0][0]): params}
			return arg(* (val for val in map(lambda x: params[self.__get_pam_name(x)],inspect.getargspec(arg)[0]) ) )
		elif isinstance(arg,str) or arg.__class__.__module__.startswith('sympy'):
			try:
				if isinstance(arg,str):
					arg = sympy.S(arg)
					fs = list(arg.free_symbols)
					if len(fs) == 1 and str(arg)==str(fs[0]):
						raise errors.ParameterInvalidError("There is no parameter, and no interpretation, of '%s' which is recognised by Parameters." % arg)
				params = {}
				for sym in arg.free_symbols:
					param = self.__get_param(str(sym),**kwargs)
					if isinstance(param,Quantity):
						raise errors.SymbolicEvaluationError("Symbolic expressions can only be evaluated when using scaled parameters. Attempted to use '%s' in '%s', which would yield a united quantity." % (sym,arg))
					params[str(sym)] = self.__get_param(str(sym),**kwargs)
				return float(arg.subs(params).evalf())
			except errors.ParameterInvalidError, e:
				raise e
			except Exception, e:
				raise errors.SymbolicEvaluationError("Error evaluating symbolic statement '%s'. The message from SymPy was: `%s`." % (arg,e))
		
		raise KeyError, "There is no parameter, and no interpretation, of '%s' which is recognised by Parameters." % arg
	
	################ SET PARAMETERS ############################################
	
	def __is_valid_param(self,param):
		return re.match("^[_A-Za-z][_a-zA-Z0-9]*$",param)
	
	def __check_valid_params(self,params):
		bad = []
		for param in params:
			if not self.__is_valid_param(param):
				bad.append(param)
		if len(bad) > 0:
			raise errors.ParameterInvalidError("Attempt to set invalid parameters: %s . Parameters must be valid python identifiers matching ^[_A-Za-z][_a-zA-Z0-9]*$." % ','.join(bad) )
	
	def __set(self,**kwargs):
		
		self.__check_valid_params(kwargs)
		
		for param,val in kwargs.items():
			try:
				if isinstance(val,(types.FunctionType,str)):
					self.__parameters[param] = self.__check_function(param,self.__get_function(val))
					self.__spec(**{param:self.__get_unit('')})
				elif isinstance(val,(list,tuple)) and isinstance(val[0],(types.FunctionType,str)):
					self.__parameters[param] = self.__check_function(param,self.__get_function(val[0]))
					self.__spec(**{param:self.__get_unit(val[1])})
				else:
					self.__parameters[param] = self.__get_quantity(val,param=param)
					if isinstance(self.__parameters[param],Quantity):
						self.__spec(**{param:self.__parameters[param].units})
				if param in dir(type(self)):
					warnings.warn(errors.ParameterNameWarning("Parameter '%s' will not be accessible using the attribute notation `p.%s`, as it conflicts with a method name of Parameters."%(param,param)))
			except Exception, e:
				raise errors.ParametersException("Could not add parameter %s. %s" % (param, e))
	
	def __update(self,**kwargs):
		
		self.__check_valid_params(kwargs)
		
		self.__process_override(kwargs,abort_noninvertable=True)
		
		for param,value in kwargs.items():
			if param not in self.__parameters or not isinstance(self.__parameters.get(param),types.FunctionType):
				self.__set(**{param:kwargs[param]})
	
	def __and__(self,other):
		if not isinstance(other,dict):
			raise errors.ParametersException("The binary and operator is used to set the unit specification for parameters; and requires a dictionary of units.")
		self.__spec(**other)
	
	def __spec(self, **kwargs):
		''' Set units for parameters. '''
		for arg in kwargs:
			self.__parameters_spec[arg] = self.__get_unit(kwargs[arg])
			if self.__parameters.get(arg) is not None:
				self.__parameters[arg].units = self.__parameters_spec[arg]
	
	def __remove(self,param):
		if param in self.__parameters:
			del self.__parameters[param]
		if param in self.__parameters_spec:
			del self.__parameters_spec[param]
	
	def __sub__(self,other):
		if not isinstance(other,str):
			raise errors.ParameterInvalidError("The subtraction operator is used to remove parameters; and a parameter name string must be provided.")
		
		self.__remove(other)
		return self
	
	def __lshift__(self,other):
		
		if not isinstance(other,dict):
			raise errors.ParametersException("The left shift operator sets parameter values without interpretation; such as functions. It accepts a dictionary of parameter values.")
		
		self.__set(**other)
		return self
	
	def __sympy_to_function(self,expr):
		try:
			expr = sympy.S(expr)
			syms = list(expr.free_symbols)
			f = sympy.utilities.lambdify(syms,expr)

			o = {}
			exec ('def g(%s):\n\treturn f(%s)'%( ','.join(map(str,syms)) , ','.join(map(str,syms)) ) , {'f':f},o)

			return o['g']
		except:
			raise errors.SymbolicEvaluationError( 'String \'%s\' is not a valid symbolic expression.' % (expr) )
	
	def __get_function(self,expr):
		if isinstance(expr,types.FunctionType):
			return expr
		return self.__sympy_to_function(expr)
		
	def __check_function(self,param,f,forbidden=None):
		args = inspect.getargspec(f).args
		
		while param in args:
			args.remove(param)
		
		if forbidden is None:
			forbidden = []
		else:
			for arg in forbidden:
				if arg in args:
					raise errors.ParameterRecursionError( "Adding function would result in recursion with function '%s'" % arg )
		forbidden.append(param)
		
		for arg in args:
			if isinstance(self.__parameters.get(arg,None),types.FunctionType):
				self.__check_function(arg,self.__parameters.get(arg),forbidden=forbidden[:])
		
		return f
	
	def __unit_scale(self,unit):
		for scale in self.__unit_scalings:
			if scale[0] == unit.dimensions:
				return scale[1]
		return 1.0
	
	def __basis_scale(self,unit):
		unit = self.__get_unit(unit)
		scaling = Quantity(1,None,dispenser=self.__units)
		
		for dim,power in unit.dimensions.items():
			scaling *= self.__scalings.get(dim,Quantity(1,self.__units.basis()[dim],dispenser=self.__units))**power
		
		return scaling
	
	def __unit_scaling(self,unit):
		'''
		Returns the float that corresponds to the relative scaling of the
		provided unit compared to the intrinsic scaling basis of the parameters.
		
		dimensionless value = quantity / unit_scaling = quantity * unit_scale / basis_scale
		'''
		
		if unit in self.__scaling_cache:
			return self.__scaling_cache[unit]
		
		scale = self.__basis_scale(unit)
		scaling = scale.value*scale.units.scale(unit)/self.__unit_scale(unit)
		
		self.__scaling_cache[unit] = scaling
		return scaling
		
	################ EXPOSE PARAMETERS #########################################
	def __call__(self,*args,**kwargs):
		
		if args:
			return self.__get(*args,**kwargs)
		
		self.__update(**kwargs)
		return self
	
	def __table(self,table):
		
		def text_len(text):
			if '\033[' in text:
				return len(text) - 11
			return len(text)
		
		def column_width(i,text):
			if '\033[' in text:
				return col_width[i] + 11
			return col_width[i]
		
		col_width = [max(text_len(x) for x in col) for col in zip(*table)]
		output = []
		for line in table:
			output.append( "| " + " | ".join("{:^{}}".format(x,column_width(i,x)) for i, x in enumerate(line)) + " |" )
		
		return '\n'.join(output)
	
	@property
	def repr(self):
		if len(self.__parameters) == 0:
			return 'No parameters have been specified.'
		
		parameters = [ [colour_text('Parameter','WHITE',True),colour_text('Value','WHITE',True),colour_text('Scaled','WHITE',True)] ]
		for param in sorted(self.__parameters.keys()):
			
			if self.__default_scaled:
				key_scaled,key = param,'_%s'%param
			else:
				key_scaled,key = '_%s'%param, param
			
			if isinstance(self.__parameters[param],types.FunctionType):
				v = 'Unknown'
				vs = 'Unknown'
				try:
					v = str(self.__get(key))
					vs = str(self.__get(key_scaled))
				except:
					pass
				parameters.append( [ 
					'%s(%s)' % ( param, ','.join(inspect.getargspec(self.__parameters[param])[0] ) ),
					v,
					vs  ] )
				
			else:
				parameters.append( [param, str(self.__get(key)),str(self.__get(key_scaled))] )
		
		for param in sorted(self.__parameters_spec.keys()):
			if param not in self.__parameters:
				parameters.append( [colour_text(param,'CYAN'), colour_text("- %s" % self.__parameters_spec[param],'CYAN'),colour_text("-",'CYAN')] )
		
		return self.__table(parameters)
	
	def __repr__(self):
		return "< Parameters with %d definitions >" % len(self.__parameters)
		
	def __dir__(self):
	    res = dir(type(self)) + list(self.__dict__.keys())
	    res.extend(self.__parameters.keys())
	    return res
	
	def __getattr__(self,name):
		if name[:2] == "__":
			raise AttributeError
		return self.__get(name)
	
	################## PARAMETER BOUNDS ####################################
	
	def set_bounds(self,bounds_dict,error=True,clip=False):
		if not isinstance(bounds_dict,dict):
			raise ValueError("Bounds must be specified as a dictionary. Provided with: '%s'." % (bounds))
		for key,bounds in bounds_dict.items():
			if not isinstance(bounds,list):
				bounds = [bounds]
			bounds_new = []
			for bound in bounds:
				if not isinstance(bound,tuple) or len(bound) != 2:
					raise ValueError("Bounds must be of type 2-tuple. Received '%s'."%(bound))
				
				lower = bound[0]
				if lower is None:
					lower = (-np.inf,self.units(key))
				lower = self.__get_quantity(lower,param=key)
				
				upper = bound[1]
				if upper is None:
					upper = (np.inf,self.units(key))
				upper = self.__get_quantity(upper,param=key)
				bounds_new.append( (lower,upper) )
				
			self.__parameters_bounds[key] = Bounds(key,self.units(key),bounds_new,error=error,clip=clip)
	
	def __getitem__(self,key):
		return self.__parameters_bounds[key].bounds
	
	def __setitem__(self,key,value):
		self.set_bounds({key:value})
		
	################## RANGE UTILITY #######################################
	
	def range(self,*args,**ranges):
		values = None
		static = {}
		lists = {}
		
		count = None
		for param,range in ranges.items():
			range = self.__range_interpret(param,range)
			if isinstance(range,(list,np.ndarray)):
				lists[param] = range
				count = len(range) if count is None else count
				if count != len(range):
					raise ValueError("Not all parameters have the same range")
			else:
				static[param] = range
		
		if count is None:
			return self.__get(*args,**ranges)
		
		for i in xrange(count):
			d = {}
			d.update(static)
			for key in lists:
				d[key] = lists[key][i]
			
			argvs = self.__get(*args,**d)
			
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
	
	def __range_interpret(self,param,pam_range):
		if isinstance(pam_range,tuple) and len(pam_range) in [3,4]:
			start,end,count,sampler = 0,1,1,np.linspace
			
			if len(pam_range) == 4: # Then assume format (start, end, count, sampler), with sampler(start,stop,count)
				start,end,count,sampler = pam_range
			elif len(pam_range) == 3: # Then assume format (start, end, count)
				start,end,count = pam_range
			else:
				raise ValueError, "Unknown range specification format: %s." % pam_range
			
			if isinstance(sampler,str):
				if sampler == 'linear':
					sampler = np.linspace
				elif sampler == 'log':
					def logspace(start,end,count):
						logged = np.logspace(1,10,count)
						return (logged-logged[0])*(end-start)/logged[-1]+start
					sampler = logspace
				elif sampler == 'invlog':
					def logspace(start,end,count):
						logged = np.logspace(1,10,count)
						return (logged[::-1]-logged[0])*(end-start)/logged[-1]+start
					sampler = logspace
				else:
					raise ValueError, "Unknown sampler: %s" % sampler
			
			return sampler(
					self.__get_quantity(start,param=param,scaled=True),
					self.__get_quantity(end,param=param,scaled=True),
					count
					)
		return pam_range
	
	################## CONVERT UTILITY #####################################
	def asvalue(self,**kwargs):
		d = {}
		for param, value in kwargs.items():
			d[param] = self.convert(value,output=self.units(param),value=True)
		if len(d) == 1:
			return d.values()[0]
		return d

	def asscaled(self,**kwargs):
		d = {}
		for param, value in kwargs.items():
			d[param] = self.convert(value)
		if len(d) == 1:
			return d.values()[0]
		return d

	def units(self,*params):
		l = list(self.__parameters_spec.get(param,None) for param in params)
		if len(params) == 1:
			return l[0]
		return l

	def convert(self, quantity, input=None, output=None, value=False):

		if isinstance(quantity,Quantity):
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
	
	def optimise(self,param):
		'''
		Optimise the parameter query operator to fast operation times.
		'''
		
		if param is None or isinstance(param,types.FunctionType) or self.__is_valid_param(param):
			return param
		
		elif isinstance(param,str):
			return self.__sympy_to_function(param)
		
		raise errors.ExpressionOptimisationError("No way to optimise parameter expression: %s ." % param)

	################## LOAD / SAVE PROFILES ################################
	
	@classmethod
	def load(cls, filename, **kwargs):
		profile = imp.load_source('profile', filename)
		
		p = cls(**kwargs)
		
		p*getattr(profile,"dimension_scalings",{})
		
		for unit_scaling in getattr(profile,"unit_scalings",[]):
			p*unit_scaling
		
		for unit in getattr(profile,"units_custom",[]):
			p+unit
		
		p(**getattr(profile,"parameters",{}))
		
		return p
	
	def __rshift__(self,other):
		
		if not isinstance(other, str):
			raise errors.ParametersException("The right shift operator is used to save the parameters to a file. The operand must be a filename.")
		
		self.__save__(other)
		return self
	
	def __save__(self, filename):
		f = open(filename,'w')
		
		# Export dimension scalings
		f.write( "dimension_scalings = {\n" )
		for dimension,scaling in self.__scalings.items():
			f.write("\t\"%s\": (%s,\"%s\"),\n"%(dimension,scaling.value,scaling.units))
		f.write( "}\n\n" )
		
		# Export unit scalings
		f.write( "unit_scalings = {\n" )
		for scaling in self.__unit_scalings:
			f.write("%s,\n"%unit)
		f.write( "}\n\n" )
		
		# Export custom units
		f.write( "units_custom = {\n" )
		for unit in self.__units_custom:
			f.write("%s,\n"%unit)
		f.write( "}\n\n" )
		
		# Export parameters
		f.write( "parameters = {\n" )
		for pam,value in self.__parameters.items():
			f.write("\t\"%s\": (%s,\"%s\"),\n"%(pam,value.value,value.units))
		f.write( "}\n\n" )
		
		f.close()

class Bounds(object):
	
	def __init__(self,param,units,bounds,error=True,clip=False):
		self.param = param
		self.units = units
		self.bounds = bounds
		self.error = error
		self.clip = clip
	
	def check(self,value):
		within_bounds = False
		for bound in self.bounds:
			if bound[0] < value and bound[1] > value:
				within_bounds = True
				break
		
		if within_bounds:
			return value
		
		if self.clip:
			warnings.warn( errors.ParameterOutsideBoundsWarning("Value %s for '%s' outside of bounds %s. Clipping to nearest allowable value." % (value, self.param, self.bounds)) )
			blist = []
			for bound in self.bounds:
				b.extend(bound)
			dlist = map( lambda x: abs(x-value) , bounds)
			return blist(np.where(dlist==np.min(dlist)))
		elif self.error:
			raise errors.ParameterOutsideBoundsError("Value %s for '%s' outside of bounds %s" % (value, self.param, self.bounds))
		
		warnings.warn( errors.ParameterOutsideBoundsWarning("Value %s for '%s' outside of bounds %s. Using value anyway." % (value, self.param, self.bounds)) )
		return value
