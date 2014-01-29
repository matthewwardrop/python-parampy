parameters
==========

A python library that takes care of physical quantities; including unit conversions and scalings.

Installation
------------

In most cases, installing this module is as easy as:

$ python2 setup.py install

If you run Arch Linux, you can instead run:

$ makepkg
$ pacman -U python2-parameters-<version>-1-<arch>.pkg.tar.xz

Documentation
-------------

The following is the documentation included within the Parameters object:

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
