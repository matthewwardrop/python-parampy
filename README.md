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
