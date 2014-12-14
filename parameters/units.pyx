from fractions import Fraction
import re

from . import errors
from .text import colour_text


class Unit(object):
	'''
	Unit (names,abbr=None,rel=1.0,prefixable=True,plural=None,dimensions={})

	The fundamental unit object.

	Parameters
	----------
	names : A string or list of strings that are used as full names for this
		unit.
	abbr : A string that will be used to represent the abbreviated unit.
	rel : The size of this unit compared to some fixed arbitrary basis. For
		clarity, the SI basis is used in this module.
	prefixable : Whether or not the unit can be prefixed (e.g. milli, micro,
		etc).
	plural : When written in full, use this string as the plural unit. Note
		that when this is not provided, an 's' is appended to the
		unit.
	dimensions : A dictionary that describes the dimensions of this unit.
		These dimensions can be any string; i.e. {'length':1, 'mass':-2}
		would describe a unit that in SI units could be represented as
		"m/kg^2" . Note that you can invent your own dimensions to; such as:
		"intelligence"; or even change the basis of the SI units so that
		"energy" is a base dimension. So long as you do this consistently
		in all of your units, everything will work fine.

	Examples
	--------

	Creating a unit is easy:
	>>> u = Unit('metre',abbr='m',rel=1.0,dimensions={'length':1,'mass':-2})

	You can also defer adding the dimensions, or change the dimensions using:
	>>> u.set_dimensions(length=1,mass=-2)
	The set_dimensions object returns the Unit object itself, so that it can
	be chained.

	'''

	def __init__(self, names, abbr=None, rel=1.0, prefixable=True, plural=None, dimensions={}):
		self.names = names if isinstance(names, (tuple, list)) else [names]
		self.abbr = abbr
		self.plural = plural

		self.rel = rel
		self.prefixable = prefixable

		self.dimensions = dimensions

	def set_dimensions(self, **dimensions):
		self.dimensions = dimensions
		return self

	def __repr__(self):
		return self.names[0]


class UnitDispenser(object):
	'''
	UnitDispenser()

	An object that manages a collection of Unit objects, and generates Units
	objects from them. Most of the methods attached to this object modify
	the Unit objects attached to this object; only calling the object retrieves
	a Units object.

	One can subclass the UnitDispenser object and implement the
	UnitsDispenser.[init_prefixies,init_units] methods to prepopulate the
	UnitDispenser object with units.


	Examples
	--------

	Create a UnitDispenser object.
	>>> ud = UnitDispenser()

	Add a unit to the pool of available Unit objects. See documentation for
	`Unit`. For example:
	>>> ud.add( Unit('metre',abbr='m',rel=1.0).set_dimensions(length=1,mass=-2) )
	Alternatively, one can also add predefined Unit objects.
	>>> ud + Unit('metre',abbr='m',rel=1.0).set_dimensions(length=1,mass=-2)
	Note that when adding a unit, it will replace any existing unit by the
	same name; and that if Unit.prefixable is True, then it will add the unit
	as well as the prefixed versions of itself.

	A list of the units available in the UnitDispenser are retrievable using:
	>>> ud.list()

	You can check if a unit is included in the dispenser by running:
	>>> ud.has('metre')

	To retrieve a Unit object from the pool, you can run:
	>>> ud.get('metre')

	Each UnitDispenser object also keeps track of which dimensions its'
	units span. This can be retrieved using:
	>>> ud.dimensions

	For each of the dimensions, it maintains a default base unit for that
	dimension. This then acts as a basis for the rest of the units. This
	basis will automatically select a unit when it is added, if a unit is
	added that has only that dimension with a order of 1 (e.g. length=1, etc).
	This basis can be retrieved:
	>>> ud.basis()
	and modified:
	>>> ud.basis(length='metre')

	And most importantly, the way to extract Units objects from a
	UnitDispenser is to call the object with the desired string
	representation of the Units.
	>>> ud('m^2/kg^2')
	This is also equivalent to:
	>>> ud('m^2*kg^-2')
	You can also call it with a Unit object, a Units object, or a dictionary
	of Unit-power relations.
	'''

	def __init__(self):
		self._dimensions = {}
		self._units = {}
		self._prefixes = []

		self.__cache = {}

		self.init_prefixes()
		self.init_units()

	############# SETUP ROUTINES ###########################################
	def init_prefixes(self):
		'''
		A hook to allow subclasses to populate themselves.
		'''
		pass

	def init_units(self):
		'''
		A hook to allow subclasses to populate themselves.
		'''
		pass

	def add(self, unit, check=True):
		if not isinstance(unit, Unit):
			raise errors.UnitInvalidError("A Unit object is required for addition to a UnitDispenser. Was provided with: '%s'." % unit)

		for name in unit.names:
			self._units[name] = unit
		if unit.abbr != None:
			self._units[unit.abbr] = unit

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
						names="%s%s" % (prefix[0], unit.names[0]),
						abbr="%s%s" % (prefix[1], unit.abbr) if unit.abbr is not None else None,
						plural="%s%s" % (prefix[0], unit.plural) if unit.plural is not None else None,
						rel=unit.rel * prefix[2],
						prefixable=False
					).set_dimensions(**unit.dimensions),
					check=False)

	def __add__(self, unit):
		self.add(unit)
		return self

	def list(self):
		return self._units.keys()

	def has(self, identifier):
		return identifier in self._units

	def get(self, unit):
		if isinstance(unit, str):
			try:
				return self._units[unit]
			except:
				raise errors.UnitInvalidError("Unknown unit: '%s'." % unit)
		elif isinstance(unit, Unit):
			return unit
		raise errors.UnitInvalidError("Could not find Unit object for '%s'." % unit)

	@property
	def dimensions(self):
		return self._dimensions.keys()

	def basis(self, **kwargs):
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


class Units(object):
	'''
	Units(units=None,dispenser=None)

	The object describing all possible arrangements of Unit objects; and
	that handles all unit arithmetic.

	Parameters
	----------
	units : A representation of the units in some form. This can be:
		- A Units object
		- A Unit object
		- A string representing a units object
		- A dictionary of Unit-power relationships
	dispenser : A UnitDispenser instance from which the units can be drawn.

	Examples
	--------

	Most of the magic is of the Units of object is done behind the scenes.
	In particular, if you multiply or divide two units objects, then a new
	Units object is returned with the appropriate units. It is unlikely
	though that you will want to use Units objects directly; but rather
	the Quantity object, which combines the units with a value.

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
			return units

		elif isinstance(units, str):
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

		output = []

		items = sorted(self.__units.items())

		if self.dimensions == {}:
			return "units"

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

	def scale(self, scale):
		'''
		Returns a float comparing the current units to the provided units.
		'''
		try:
			return self.__scale_cache[scale]
		except:
			if getattr(self, '__scale_cache', None) is None:
				self.__scale_cache = {}

			if isinstance(scale, str):
				scale = self.__dispenser(scale)

			dims = self.dimensions
			dims_other = scale.dimensions

			# If the union of the sets of dimensions is less than the maximum size of the dimensions; then clearly the units are the same.
			if len(set(dims.items()) & set(dims_other.items())) < max(len(dims), len(dims_other)):
				raise errors.UnitConversionError("Invalid conversion. Units '%s' and '%s' do not match. %s" % (self, scale, set(dims.items()) & set(dims_other.items())))
			self.__scale_cache[scale] = self.rel / scale.rel
			return self.__scale_cache[scale]

	@property
	def dimensions(self):
		# if getattr(self,'__dimensions',None) is not None:
		# 	return self.__dimensions.copy()

		dimensions = {}
		for unit, power in self.__units.items():
			for key, order in unit.dimensions.items():
				dimensions[key] = dimensions.get(key, 0) + power * order
		for key, value in list(dimensions.items()):
			if value == 0:
				del dimensions[key]

		# self.__dimensions = dimensions

		return dimensions  # .copy()

	@property
	def rel(self):
		'''
		Return the relative size of this unit (compared to other units from the same unit dispenser)
		'''

		rel = 1.
		for unit, power in self.__units.items():
			rel *= unit.rel ** power
		return rel

	@property
	def basis(self):
		dimensionString = ""
		dimensionMap = self.__dispenser.basis()
		dimensions = self.dimensions

		for dimension in self.dimensions:
			if dimensions[dimension] != 0:
				dimensionString += "*%s^%f" % (dimensionMap[dimension].abbr if dimensionMap[dimension].abbr is not None else dimensionMap[dimension], float(dimensions[dimension]))

		return Unit(dimensionString[1:], dispenser=self.__dispenser)

	@property
	def units(self):
		return self.__units.copy()

	########### UNIT OPERATIONS ############################################

	def __new(self, units):
		return Units(units, self.__dispenser)

	def copy(self):
		return Units(self.units, self.__dispenser)

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
		return self.__new(self.__mul_units(self.units, other.units))

	def __div__(self, other):
		return self.__new(self.__div_units(self.units, other.units))

	def __truediv__(self, other):
		return self.__div__(other)

	def __rdiv__(self, other):
		if other == 1:
			return self.__pow__(-1)
		raise ValueError("Units cannot have numerical size.")

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
