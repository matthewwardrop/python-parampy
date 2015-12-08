from fractions import Fraction
import re, types, inspect

from . import errors
from .text import colour_text
from .utility.compat import UnicodeMixin, str_types


class Unit(UnicodeMixin):
	'''
	Unit (name,abbr=None,rel=1.0,prefixable=True,plural=None,dimensions={},base_unit=None)

	:class:`Unit` is the fundamental object which represents a single unit in units
	specification. For example, in "m*s", each of "m" and "s" would have their own
	associated :class:`Unit` object.

	:param name: A string or list of strings that are used as full names for this unit. If more than one is provided, the first is used as the default representation.
	:type name: str or list of str
	:param abbr: A string or list of strings that will be used to represent the abbreviated unit. If more than one is provided, the first is used as the default representation.
	:type abbr: str or list of str
	:param rel: The size of this unit compared to some fixed arbitrary basis.
	:type rel: float
	:param prefixable: Whether or not the unit can be prefixed (e.g. milli, micro, etc).
	:type prefixable: bool
	:param plural: When written in full, use this string as the plural unit. Note that when this is not provided, where implemented, an 's' is appended to the unit.
	:type plural: str
	:param dimensions: A dictionary specification of the dimensions of this unit.
	:type dimensions: dict
	:param base_unit: A Unit object corresponding to the base unit (if this unit is prefixed), or None otherwise.
	:type base_unit: Unit

	To instantiate a :class:`Unit` object, you can use something like:
	>>> u = Unit('metre',abbr='m',rel=1.0,dimensions={'length':1})

	Note that the keys for the dimensions can be whatsoever you please, and that
	you can invent your own dimensions. For example, you could create a unit with
	dimensions of "intelligence". The :class:`UnitDispenser` instance will pick up
	this dimension and handle unit conversions/etc, where that makes sense. The
	values of the dimensions dictionary indicate the power to which the dimension
	specified in the key should be taken.
	'''

	def __init__(self, name=None, abbr=None, rel=1.0, prefixable=True, plural=None, dimensions=None, base_unit=None):
		self.name = name
		self.abbr = abbr
		self.plural = plural

		self.rel = rel
		self.prefixable = prefixable

		self.dimensions = dimensions

		self.base_unit = base_unit if base_unit is not None else self

	@property
	def name(self):
		'''
		The default full name for this unit.

		To set the name(s) for this unit, you can use:

		>>> u.name = "meter"

		Or, if you want to provide multiple names as an alias.

		>>> u.name = ["meter","metre"]
		'''
		return self.__names[0]
	@name.setter
	def name(self, name):
		if name is None:
			raise ValueError("Unit objects require a valid name.")
		self.__names = name if isinstance(name, (tuple, list)) else (name,)
	@property
	def names(self):
		'''
		The full list or tuple of names specified for this unit.
		'''
		return self.__names

	@property
	def abbr(self):
		'''
		The default abbreviation for this unit.

		To set the name(s) for this unit, you can use:

		>>> u.abbr = "m"

		Or, if you want to provide multiple names as an alias.

		>>> u.abbr = ["m","<abbr>"]
		'''
		if self.__abbrs is None:
			return None
		return self.__abbrs[0]
	@abbr.setter
	def abbr(self, abbr):
		if abbr is None:
			self.__abbrs = None
		else:
			self.__abbrs = abbr if isinstance(abbr, (tuple, list)) else (abbr,)
	@property
	def abbrs(self):
		'''
		abbrs(self)

		:returns: The full list or tuple of abbreviations specified for this unit.
		'''
		return self.__abbrs

	@property
	def dimensions(self):
		'''
		The dictionary of dimensions specified for this unit.

		To set the dimensions for this unit, you can use:

		>>> u.dimensions = {'length':1}

		For more about the dimensions format, refer to comments in the general
		documentation for this class.
		'''
		return self.__dimensions
	@dimensions.setter
	def dimensions(self, dimensions):
		if dimensions is None:
			dimensions = {}
		if type(dimensions) != dict:
			raise ValueError("Invalid specications of unit dimensions.")
		self.__dimensions = dimensions
	def set_dimensions(self, **dimensions):
		'''
		set_dimensions(**dimensions)

		:param dimensions: Dictionary of dimensions.
		:type dimensions: dict

		:returns: A reference to the unit object.

		This is a shorthand convenience method that allows you to construct
		units in a slightly simpler form:

		>>> u = u = Unit('metre',abbr='m',rel=1.0).set_dimensions(length=1)
		'''
		self.__dimensions = dimensions
		return self

	def __repr__(self):
		return str(self)

	def __unicode__(self):
		return self.name


class UnitDispenser(UnicodeMixin):
	'''
	UnitDispenser()

	A :class:`UnitDispenser` instance is an object that manages a collection of
	:class:`Unit` objects.

	One can subclass the UnitDispenser object and implement the
	UnitsDispenser.[init_prefixies,init_units] methods to prepopulate the
	UnitDispenser object with units. This is done for the SI unit system with the
	:class:`SIUnitDispenser` class.

	Most of the functionality of the UnitDispenser class is clear from its methods.
	The functionality which is not clear from reading the documentation of the methods
	is introduced here.

	Creating a UnitDispenser instance:
		>>> ud = UnitDispenser()

	Generating Units objects:
		To generate a :class:`Units` object which represents a particular combination
		of individual :class:`Unit` objects, you can call this class with a string
		representing the units. For example:

		>>> ud('m*s')
		m*s

		This is shorthand for calling:

		>>> Units('m*s',dispenser=ud)
		m*s

		In addition to being shorter, the Units object is cached in the UnitDispenser
		object for future recall. See the documentation for :class:`Units` for more.

		For non-compound units, you can also use:

		>>> ud.km

		Which is shorthand for:

		>>> ud('km')
	'''

	def __init__(self):
		self._dimensions = {}
		self._units = {}
		self._prefixes = []

		self._contexts = {}
		self._context_current = False
		self._scalings = {}
		self._conversions = {}
		self.__convertable_units = []
		self.__conversions_cache = {}

		self.__cache = {}

		self.init_prefixes()
		self.init_units()

	############# SETUP ROUTINES ###########################################
	def init_prefixes(self):
		'''
		init_prefixes()

		A stub to allow subclasses to populate themselves.
		'''
		pass

	def init_units(self):
		'''
		init_units()

		A stub to allow subclasses to populate themselves.
		'''
		pass

	def add(self, unit, check=True):
		'''
		add(unit, check=True)

		:param unit: The unit to be added to the UnitDispenser.
		:type unit: Unit
		:param check: Whether to check that there is a basis unit for every dimension used by the :class:`Unit` object.
		:type check: bool

		:returns: A reference to self, for chaining.

		This method adds the supplied :class:`Unit` object to the dispenser's
		catalog of known units. If the unit object has a dimension of type never
		seen before by the dispenser, and the unit has no other dimensions, it is
		made the default "basis" for that dimension. If the unit has other dimensions
		as well, then a warning is printed stating that no basis element is known for that
		dimension.

		To add a unit (or units), you can use:

		>>> ud.add( Unit('metre',abbr='m',rel=1.0).set_dimensions(length=1,mass=-2) ).add( .... )

		You can also use the shorthand:

		>>> ud + Unit('metre',abbr='m',rel=1.0).set_dimensions(length=1,mass=-2) + .....

		.. warning:: When adding a unit, the dispenser will replace any existing unit by the same name; and that if Unit.prefixable is True, then it will add the unit as well as all possible prefixed versions of that unit.
		'''
		if not isinstance(unit, Unit):
			raise errors.UnitInvalidError("A Unit object is required for addition to a UnitDispenser. Was provided with: '%s'." % unit)

		for name in unit.names:
			self._units[name] = unit
		if unit.abbr != None:
			for abbr in unit.abbrs:
				self._units[abbr] = unit

		for dimension in unit.dimensions:
			if dimension not in self._dimensions or self._dimensions[dimension] is None:
				if unit.dimensions == {dimension: 1}:
					self.basis(**{dimension: unit})
				else:
					self._dimensions[dimension] = None
		if check:
			for dimension, basis_unit in self.basis().items():
				if basis_unit is None:
					print colour_text("WARNING: No basis unit specified for: %s." % dimension)

		if unit.prefixable:
			for prefix in self._prefixes:
				self.add(
					Unit(
						name=self.__generate_units(unit.names, prefix[0]),
						abbr=self.__generate_units(unit.abbrs, prefix[1]),
						plural=self.__generate_units(unit.plural, prefix[0]),
						rel=unit.rel * prefix[2],
						prefixable=False,
						base_unit=unit
					).set_dimensions(**unit.dimensions),
					check=False)

		return self

	def add_context(self, *name, **params):
		if params == {} and len(name) == 2:
			params = name[1]
			name = name[0]
		else:
			assert(len(name) == 1)
			name = name[0]
		self._contexts[name] = params

	def set_context(self, *name, **params):
		assert(len(name) == 1)
		name = name[0]

		if name not in self._contexts:
			raise ValueError("Non-existent context %s" % name)

		ps = self._contexts[name].copy()

		for p in ps.keys():
			if p in params:
				ps[p] = params[p]

		self._context_current = (name, ps)
		self.__cache = {}

	@property
	def context(self):
		if self._context_current is False:
			return None
		else:
			return self._context_current

	def add_scaling(self, dim_from, dim_to, scaling, context=None):
		'''
		add_scaling(dim_from, dim_to, scaling, context=None)

		:param dim_from: A dictionary of dimensions from which scaling will be provided to `dim_to`.
		:type dim_from: dict
		:param dim_to: A dictionary of dimensions to which scaling will be provided from `dim_from`.
		:type dim_to: dict
		:param scaling: The scaling to be acquired.
		:type scaling: float
		:param context: The context to which this scaling belongs.
		:type context: string

		This method adds a scaling between units of different dimensions that
		can be used to simplify computations in different physical contexts.
		For example, in many condensed matter physics, energies are often
		discussed as frequencies (and vice versa).

		Using:

		>>> ud.add_scaling( ud.joule.dimensions, ud.hertz.dimensions, 1./2/hbar/pi, context='condensed_matter' )

		Will allow you to do:

		>>> SIQuantity( 2, 'J' )('GHz', context='condensed_matter')
		'''
		assert(type(dim_from) == dict)
		assert(type(dim_to) == dict)
		if context not in self._contexts:
			self._contexts[context] = {}
		if context not in self._scalings:
			self._scalings[context] = []
		self._scalings[context].append( (dim_from, dim_to, scaling) )

	def is_scalable(self, dim_from, dim_to, context=False):
		'''
		is_scalable(dim_from, dim_to, context=False)

		:param dim_from: A dictionary of dimensions from which scaling to `dim_to` will be tested.
		:type dim_from: dict
		:param dim_to: A dictionary of dimensions to which scaling from `dim_from` will be tested.
		:type dim_to: dict
		:param context: The context in which to test this scaling.
		:type context: str

		This method returns `True` if there is a special scaling specified
		between the dimensions provided.
		'''
		try:
			self.scale(dim_from, dim_to, context=context)
			return True
		except:
			return False

	def scale(self, dim_from, dim_to, context=False):
		'''
		scale(dim_from, dim_to, context=False)

		:param dim_from: A dictionary of dimensions from which to scale.
		:type dim_from: dict
		:param dim_to: A dictionary of dimensions to which to scale.
		:type dim_to: dict
		:param context: The context in which to provide this scaling, or False.
		:type context: str

		This method returns a float corresponding to a scaling from the
		dimensions provided, as specified using `UnitDispenser.add_scaling`.
		'''

		if context is False:
			if self._context_current is not False:
				context = self._context_current[0]
			else:
				context = None

		if context in self._scalings:
			for scaling in self._scalings[context]:
				if dim_from == scaling[0] and dim_to == scaling[1]:
					return self.__eval_context_function(scaling[2], context)
				elif dim_from == scaling[1] and dim_to == scaling[0]:
					return 1./self.__eval_context_function(scaling[2], context)

		if context is not None:
			return self.scale(dim_from, dim_to, context=None)

		raise ValueError("No scaling between dimensions %s and %s are possible." % (dim_from, dim_to))

	def __eval_context_function(self, f, context, args=(), kwargs={}):
		if not type(f) is types.FunctionType:
			return f

		if f.__code__ is None:
			raise ValueError("Error during evaluation of function, due to its being non-introspectable. Most likely, this function is a cython function.")

		args = list(args)
		arg_names = f.__code__.co_varnames[len(args):f.__code__.co_argcount]

		for arg in arg_names:
			if arg in kwargs:
				args.append(kwargs[arg])
			elif self._context_current is not False and context == self._context_current[0] and arg in self._context_current[1]:
				args.append(self._context_current[1][arg])
			elif context in self._contexts and arg in self._contexts[context]:
				args.append(self._contexts[context][arg])
			else:
				raise ValueError("Value for `%s` not available in context." % arg)

		return f(*args)

	def add_conversion_map(self, unit_from, unit_to, mapping, absolute=False, context=None):
		'''
		add_conversion_map(unit_from, unit_to, mapping, absolute=True, context=None)

		:param unit_from: The units from which to convert.
		:type dim_from: str or Units
		:param unit_to: The units to which to convert.
		:type dim_to: str or Units
		:param mapping: A callable that takes a single value in units `unit_from`
			and returns a value with units `unit_to`.
		:type mapping: callable
		:param absolute: Whether the map provided is for units with an absolute scale
			or a relative one (i.e. fahrenheit -> celcius depends on whether
			stored values are absolute or delta values).
		:type absolute: bool
		:param context: The context in which to provide this conversion.
		:type context: str

		This method adds a potentially non-linear mapping between units that
		can be used to simplify computations in different physical contexts.
		For example, it may be useful to use store data in 'decibels', and later
		convert this to a linear value. This can be handled automatically.

		Using:

		>>> ud.add_scaling( 'dB', '', lambda v: 10**(v/10.), absolute=True, context=None )

		Will allow you to do:

		>>> SIQuantity( 1, 'dB' )('')

		'''
		# TODO: Add checks
		if context not in self._contexts:
			self._contexts[context] = {}
		if context not in self._conversions:
			self._conversions[context] = []
		self._conversions[context].append( ( self(unit_from), self(unit_to), mapping, absolute) )
		self.__convertable_units.append(self(unit_from))

	def has_conversion_map(self, unit_from, unit_to, absolute=False, context=False):
		'''
		has_conversion_map(unit_from, unit_to, absolute=True, context=None)

		:param unit_from: The units from which to convert.
		:type dim_from: str or Units
		:param unit_to: The units to which to convert.
		:type dim_to: str or Units
		:param absolute: Whether the map found is an an absolute conversion
			or a relative one (i.e. fahrenheit -> celcius depends on whether
			stored values are absolute or delta values).
		:type absolute: bool
		:param context: The context in which to provide this conversion.
		:type context: str

		This method returns `True` if there exists a conversion between the provided
		units, as specified using `UnitDispenser.add_conversion_map`.
		'''
		try:
			self.conversion_map(unit_from, unit_to, absolute=True, context=context)
			return True
		except:
			return False

	def conversion_map(self, unit_from, unit_to, absolute=False, context=False):
		'''
		conversion_map(unit_from, unit_to, absolute=True, context=None)

		:param unit_from: The units from which to convert.
		:type dim_from: str or Units
		:param unit_to: The units to which to convert.
		:type dim_to: str or Units
		:param absolute: Whether the map found should be for an absolute conversion
			or a relative one (i.e. fahrenheit -> celcius depends on whether
			stored values are absolute or delta values).
		:type absolute: bool
		:param context: The context in which to provide this conversion.
		:type context: str

		This method returns a function that when called upon the value associated
		with a quantity of units `unit_from` will return the appropriate value
		for a new quantity with units `unit_to`. This method only returns
		such a function for definitions provided to `UnitDispenser.add_conversion_map`.
		'''
		unit_from, unit_to = self(unit_from), self(unit_to)
		if unit_from not in self.__convertable_units:
			raise ValueError("No mapping known between %s and %s" % (unit_from, unit_to))

		if context is False:
			if self._context_current is not False:
				context = self._context_current[0]
			else:
				context = None

		check = False
		try:
			c = self.__conversions_cache[context][unit_from][unit_to][absolute]
			if c is None:
				check=False
			else:
				return c
		except KeyError:
			check = True

		if check and context in self._conversions:
			unit_from, unit_to = self(unit_from), self(unit_to)
			m = lambda u: u.base_unit.name

			c = None
			for conversion in self._conversions[context]:
				if conversion[-1] != absolute:
					continue
				# Try to convert current unit to stored unit
				try:
					assert(sorted(map(m, conversion[0].units.keys())) == sorted(map(m, unit_from.units.keys())))
					assert(sorted(map(m, conversion[1].units.keys())) == sorted(map(m,unit_to.units.keys())))
					pre_scaling = unit_from.scale(conversion[0])
					post_scaling = unit_to.scale(conversion[1])

					c = lambda v: self.__eval_context_function(conversion[2], context, args=[pre_scaling*v])/post_scaling

					break

				except:
					pass

			if context not in self.__conversions_cache:
				self.__conversions_cache[context] = {}
			if unit_from not in self.__conversions_cache[context]:
				self.__conversions_cache[context][unit_from] = {}
			if unit_to not in self.__conversions_cache[context][unit_from]:
				self.__conversions_cache[context][unit_from][unit_to] = {}
			self.__conversions_cache[context][unit_from][unit_to][absolute] = c

			if c is not None:
				return c

		if context is not None:
			return self.conversion_map(unit_from, unit_to, context=None)

		raise ValueError("No mapping known between %s and %s" % (unit_from, unit_to))

	def __generate_units(self, names, prefixes):
		if names is None or prefixes is None:
			return None

		if not type(names) in (list,tuple):
			names = (names,)
		if not type(prefixes) in (list,tuple):
			prefixes = (prefixes,)

		units = []
		for name in names:
			for prefix in prefixes:
				units.append("%s%s" % (prefix, name))
		return units

	def __add__(self, unit):
		self.add(unit)
		return self

	def list(self):
		'''
		list()

		:returns: A list of strings representing the units recognised by the UnitDispenser.

		For example:

		>>> ud.list()
		['m','cm','mm',...]

		Note that no particular order is guaranteed for this list.
		'''
		return self._units.keys()

	def has(self, identifier):
		'''
		has(identifier)

		:param identifier: A string representation of the unit of interest.
		:type identifier: str

		:returns: :python:`True` if the :class:`UnitDispenser` object recognises the string representation; and :python:`False` otherwise.

		For example:

		>>> ud.has('metre')
		'''

	def get(self, unit):
		'''
		get(unit)

		:param unit: A string representation of the unit of interest.
		:type unit: str

		:returns: :class:`Unit` object associated with a the string representation.
		:raises: :class:`UnitInvalidError` if no unit can be found that matches.
		'''
		if isinstance(unit, str_types):
			try:
				return self._units[unit]
			except:
				raise errors.UnitInvalidError("Unknown unit: '%s'." % unit)
		elif isinstance(unit, Unit):
			return unit
		raise errors.UnitInvalidError("Could not find Unit object for '%s'." % unit)

	@property
	def dimensions(self):
		'''
		A list of known dimensions. For example:

		>>> ud.dimensions = ['length', 'mass', 'time']
		'''
		return self._dimensions.keys()

	def basis(self, **kwargs):
		'''
		basis(**kwargs)

		:param kwargs: A dictionary of :class:`Unit` or :class:`str` objects with dimension names as keys.
		:type kwargs: dict

		This method is used to both extract and set the "basis" units for this dispenser
		instance. By default, the basis is the set of Unit objects first set with dimensions
		of {<dimension> : 1}. The only role the basis is plays is to set a standard
		canonical basis of units in which to express physical quantities.

		To examine the current basis, use:

		>>> ud.basis()

		To update or modify the basis, use:

		>>> ud.basis(length='cm', time='ns')

		For more about how this useful, see the documentation for :python:`Quantity.basis`.
		'''
		if not kwargs:
			return self._dimensions

		for key, val in kwargs.items():
			unit = self.get(val)
			if unit.dimensions == {key: 1}:
				self._dimensions[key] = unit
			else:
				print "Invalid unit (%s) for dimension (%s)" % (unit, key)

	############# UNITS GENERATION #########################################

	def __call__(self, units):
		'''
		This is a shortcut for: Units(units,dispenser=self); which also allows
		for caching.
		'''
		if type(units) is str:
			if units in self.__cache:
				return self.__cache[units]
			self.__cache[units] = Units(units, dispenser=self)
			return self.__cache[units]
		return Units(units, dispenser=self)

	def __getattr__(self, name):
		if name[:2] == "__" or name[:14] == "_UnitDispenser":
			raise AttributeError
		return self(name)


class Units(UnicodeMixin):
	'''
	Units(units=None,dispenser=None)

	The :class:`Units` object is the highest level class in python-parameters which
	deals only with units; and is the class used directly by :class:`Quantity`. It
	handles drawing appropriate units from a :class:`UnitDispenser`, and performing
	:class:`Unit` arithmetic. This arithmetic is mostly useful when used behind
	the scenes by a :class:`Quantity` instance.

	:param units: A representation of the units in some form. See below for details.
	:param dispenser: A reference to the UnitDispenser from which to draw units for this object.
	:type dispenser: UnitDispenser

	Representation of units:
		The unit representation passed to the :class:`Units` constructor can be:
			- A Units object (in which case a copy is returned)
			- A Unit object (in which case it is upgraded to a :class:`Units` object)
			- A string representing a units object
			- A dictionary of Unit-power relationships

		A valid string representation is a string which consists of a series of
		unit tokens (described below) separated by either a "* (for multiplication)
		or a "/" (for division). Each unit token consists of a unit string
		representation recognisable by a dispenser (for example: "ms" or "millisecond")
		followed by an optional power; which is indicated by a caret "^" and a floating
		point number (including integers). Importantly fractions are not supported in this
		specification.

		For example, here are some valid units string representations:
			- "kg*m*s^-2"
			- "ms/nm*kg^2"
			- "/nm"

		A valid dictionary of unit-power relationships is a mapping from :class:`Unit`
		object keys (or their string representation) to a numeric power. For example:

		>>> Units(units={"ms":1,"kg":0.5}, dispenser=ud)

	Units arithemetic:
		Units objects support the following arithmetic operations:
		- Multiplication
		- Division
		- Arbitrary powers

		For example:

		>>> ud = SIUnitDispenser()
		>>> u1 = Units('J', dispenser=ud)
		>>> u2 = Units('nm*s', dispenser=ud)
		>>> u1*ud
		J*s*nm
		>>> u1/ud
		J/s/nm
		>>> u2**2
		s^2*nm^2

		If you multiply or divide a unit object by an object other than a `Units`
		instance, a `Quantity` object will be returned. For example:

		>>> 3 * ud.nm
		3 nm

		>>> ud.nm**2 / 2
		0.5 nm^2

	Units equality:
		Units objects can also recognise when they are equal to other Units objects.

		For example (with u1 and u2 as defined above):

		>>> u1 == u2
		False
		>>> u1 != u2
		True


	There are a few useful methods though.

	To determine the numerical scaling factor between two units, you can use:
	>>> units.scale(other_units)
	This will raise an exception if the other units have different dimensions.

	The numerical scaling factor of this unit relative to the unit basis of
	the unit dispenser is given by:
	>>> units.rel

	The dimensions of the units object is given by:
	>>> units.dimensions

	The unit equivalent unit in the basis of the UnitDispenser is given by:
	>>> units.basis

	And you can see the dependence of Units on the underlying Unit objects
	directly by using:
	>>> units.units
	'''

	def __init__(self, units=None, dispenser=None):
		self.__hash = hash(str(units))
		self.__dispenser = dispenser
		self.__units = self.__process_units(units)

	def __get_unit(self, unit):
		return self.__dispenser.get(unit)

	def __process_units(self, units):

		if units is None:
			return {}

		elif isinstance(units, Units):
			return units.units.copy()

		elif isinstance(units, Unit):
			return {units: 1}

		elif isinstance(units, dict):
			units = units.copy()
			for unit in units.keys():
				if type(unit) != Unit:
					units[self.__get_unit(unit)] = Fraction(units.pop(unit))
			return units

		elif isinstance(units, str_types):
			d = {}

			if units == "units":
				return d

			for match in re.finditer("([*/])?([^*/\^0-9]+)(?:\^(\-?[0-9\.]+))?", units.replace(" ", "")):
				groups = match.groups()
				mult = -1 if groups[0] == "/" else 1
				power = mult * (Fraction(groups[2]) if groups[2] is not None else 1)

				unit = self.__get_unit(groups[1])
				d[unit] = d.get(unit, 0) + power

			return d

		raise errors.UnitInvalidError("Unrecognised unit description %s" % units)

	def __repr__(self):
		return str(self)

	def __unicode__(self):
		output = []

		items = sorted(self.__units.items(), key=str)

		for unit, power in items:
			if power > 0:
				if power != 1:
					output.append("%s^%s" % (unit.abbr, power))
				else:
					output.append(unit.abbr)
		output = "*".join(output)

		for unit, power in items:
			if power < 0:
				if power != -1:
					output += "/%s^%s" % (unit.abbr, abs(power))
				else:
					output += "/%s" % unit.abbr

		return output

	def scale(self, other, context=False, value=None):
		'''
		scale(other)

		:param other: Unit with which to compare.
		:type other: Units

		:returns: A float such that when multiplying the value of a physical quantity with this objects units it would return the value of the same physical quantity represented in 'other's units.
		:raises: UnitConversionError if "other" does not have the same dimensions as this object.

		This method returns the scaling between the units of this object and that of another.
		This method is used by the :class:`Quantity` object in order to provide unit
		conversion.

		E.g.: <km>.scale('m') -> 1000
		'''
		try:
			return self.__scale_cache[other]
		except:
			if getattr(self, '__scale_cache', None) is None:
				self.__scale_cache = {}

			if isinstance(other, str_types):
				other = self.__dispenser(other)

			dims = self.dimensions
			dims_other = other.dimensions

			scale = None
			try:
				scale = self.__dispenser.scale(dim_from=dims, dim_to=dims_other, context=context)
			except ValueError as e:
				pass

			# If the union of the sets of dimensions is less than the maximum size of the dimensions; then the units are the same.
			if scale is None:
				if len(set(dims.items()) & set(dims_other.items())) < max(len(dims), len(dims_other)):
					raise errors.UnitConversionError("Invalid conversion. Units '%s' and '%s' do not match. %s" % (self, other, set(dims.items()) & set(dims_other.items())))
				self.__scale_cache[other] = self.rel / other.rel
			else:
				return self.rel / other.rel * scale # Don't cache if scaling was applied.
			return self.__scale_cache[other]

	@property
	def dimensions(self):
		'''
		A dictionary representing the dimensions of the units described by this object.

		>>> u.dimensions
		{'length': 1, 'time': 1}
		'''

		dimensions = {}
		for unit, power in self.__units.items():
			for key, order in unit.dimensions.items():
				dimensions[key] = dimensions.get(key, 0) + power * order
		for key, value in list(dimensions.items()):
			if value == 0:
				del dimensions[key]

		return dimensions

	@property
	def rel(self):
		'''
		The relative size of this unit (compared to other units from the same unit dispenser, and with respect to an arbitrary fixed basis).

		>>> u.rel = 1.2
		'''

		rel = 1.
		for unit, power in self.__units.items():
			rel *= unit.rel ** power
		return rel

	def basis(self):
		'''
		basis()

		:returns: A new :class:`Units` object representing the units in the :class:`UnitDispenser` basis that correspond to the same dimensions as this object.

		For example:

		>>> Units('g*ns',dispenser=SIUnitDispenser()).basis()
		'kg*s'
		'''
		dimensionString = ""
		dimensionMap = self.__dispenser.basis()
		dimensions = self.dimensions

		for dimension in self.dimensions:
			if dimensions[dimension] != 0:
				dimensionString += "*%s^%f" % (dimensionMap[dimension].abbr if dimensionMap[dimension].abbr is not None else dimensionMap[dimension], float(dimensions[dimension]))

		return Units(dimensionString[1:], dispenser=self.__dispenser)

	@property
	def units(self):
		'''
		A dictionary representation of the units of this object.

		>>> u.units
		{ms: 1, kg: -1}
		'''
		return self.__units.copy()

	########### UNIT OPERATIONS ############################################

	def __new(self, units):
		return Units(units, self.__dispenser)

	def __mul_units(self, target, additive):
		for unit, power in additive.items():
			target[unit] = target.get(unit, 0) + power

			if target.get(unit, 0) == 0:
				del target[unit]
		return target

	def __div_units(self, target, additive):
		for unit, power in additive.items():
			target[unit] = target.get(unit, 0) - power

			if target.get(unit, 0) == 0:
				del target[unit]
		return target

	def __mul__(self, other):
		if not isinstance(other,Units):
			from .quantities import Quantity
			return Quantity(other, self, dispenser=self.__dispenser)
		return self.__new(self.__mul_units(self.units, other.units))

	def __rmul__(self,other):
		from .quantities import Quantity
		return Quantity(other, self, dispenser=self.__dispenser)

	def __div__(self, other):
		if not isinstance(other,Units):
			from .quantities import Quantity
			return Quantity(1./other, self, dispenser=self.__dispenser)
		return self.__new(self.__div_units(self.units, other.units))

	def __rdiv__(self,other):
		if other == 1:
			return self.__pow__(-1)
		from .quantities import Quantity
		return Quantity(other, 1/self, dispenser=self.__dispenser)

	def __truediv__(self, other):
		return self.__div__(other)

	def __rtruediv__(self, other):
		return self.__rdiv__(other)

	def __pow__(self, other):
		new_units = self.units
		for unit in new_units:
			new_units[unit] *= other
		return self.__new(new_units)

	def __eq__(self, other):
		if str(self) == str(other):
			return True
		return False

	def __hash__(self):
		return self.__hash
