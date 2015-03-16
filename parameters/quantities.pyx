import math
import errors
from functools import total_ordering
import numpy as np

from .units import UnitDispenser, Units
from .text import colour_text

class Quantity(object):
	'''
	Quantity (value,units=None,dispenser=None)

	A Quantity object represents a physical quantity; that is, one with both
	a value and dimensions. It is able to convert between different united
	representations; and keeps track of units in basic arithmetic.
	
	:param value: The value of the physical quantity in units of 'units'. Can be any python object conforming to standard numeric operations.
	:type value: Numeric
	:param units: A representation of the units of the object. See documentation of 'Units' for more information.
	:type units: str or Units
	:param dispenser: The unit dispenser object from which unit objects are drawn. If not specified, a new UnitDispenser object is created.
	:type dispenser: UnitDispenser

	Instantiate a Quantity object:
		To create a new Quantity object simply pass the value, unit representation
		and an instance of UnitDispenser to the Quantity constructor. It is important
		that the units provided are recognised by the UnitDispenser.

		>>> q = Quantity(1, 'ms', dispenser=SIUnitDispenser())

		If no dispenser is provided, it internally defaults to the empty UnitDispenser.
		A subclass named :class:`SIQuantity` is also available which defaults to the
		SIUnitDispenser; a unit dispenser prepopulated with SI units. In the rest
		of this documentation we use :class:`SIQuantity` for brevity.

	Accessing value and units separately:
		You can extract the value and units of a Quantity object separately by
		accessing the 'value' and 'units' attributes of the object.

		>>> SIQuantity(1,'ms').value
		1
		>>> SIQuantity(1,'ms').units
		'ms'

	Unit conversion:
		You can convert a Quantity object to another Quantity object with different
		units provided the dimensions agree.

		>>> SIQuantity(1,'m')('km')
		0.001 km
		>>> SIQuantity(1,'g/ns')('kg/s')
		1000000.0 kg/s

		You can also do a unit conversion and keep only the value, using the
		right shift operator:

		>>> SIQuantity(1,'m') >> 'km'
		0.001

	Representing in standard basis:
		As a special case of the unit conversion described above, you can represent
		any Quantity in the basis defined by the UnitDispenser, using the
		:func:`basis` method. The SIUnitDispenser's basis is the fundamental SI
		units.

		>>> SIQuantity(1,'km').basis()
		1000 m
		>>> SIQuantity(1,'J').basis()
		1.0 m^2*kg/s^2

	Arithmetic with Quantity objects:
		Quantity objects support basic arithmetic with the following operations:
		- Addition and subtraction with another Quantity object of the same dimensions (final units taken from first argument)
		- Multiplication and division with another Quantity object, or with a scalar numeric value.
		- Absolute values.
		- Arbitrary powers

		For convenience, Quantity objects will recognise two-tuples as a prototype
		for a Quantity, allowing for shorthand in numeric operations.

		For example:

		>>> SIQuantity(1,'ms') + (2,'s')
		2001.0 ms
		>>> (3,'km') - SIQuantity(2,'m')
		2.998 km
		>>> 2 * SIQuantity(10,'m')
		20 m
		>>> SIQuantity(10,'m') * SIQuantity(2,'s')
		20 s*m
		>>> SIQuantity(10,'m') / SIQuantity(3,'s') # Be careful with integer divison
		3 m/s # Answer is wrong because SIQuantity does not change value types.
		>> abs(SIQuantity(-5,'m'))
		5 m
		>> SIQuantity(5,'m*s')**2
		25 s^2*m^2

	Boolean logic with Quantity objects:
		Quantity objects support the following boolean operators:
		- Testing for equality and inequality
		- Testing relative size using less than and greater than

		As for arithmetic, two-tuples are automatically converted to Quantity objects
		for comparison.

		>>> SIQuantity(2,'m') == (200,'cm')
		True
		>>> SIQuantity(2,'m') != (200,'cm')
		False
		>>> SIQuantity(2,'ns') < SIQuantity(1000,'as')
		False
		>>> SIQuantity(2,'ns') > SIQuantity(1000,'as')
		True
	'''

	def __init__(self, value, units=None, dispenser=None):
		if value is None:
			raise errors.QuantityValueError("A quantity's value must not be None.")
		if isinstance(value, (list, tuple)):
			value = np.array(value)
		self.value = value
		self._dispenser = dispenser if dispenser is not None else self._fallback_dispenser()
		if not isinstance(units, Units):
			self.units = self._dispenser(units)
		else:
			self.units = units

	def basis(self):
		'''
		basis()

		:returns: Quantity object with current value expressed in the basis units of the UnitDispenser.

		For example, for the :class:`SIUnitDispenser`:

		>>> SIQuantity(1,'J').basis()
		1.0 kg*m^2/s^2
		'''
		return self(self.units.basis())

	def _new(self, value, units, dispenser=None):
		return Quantity(value, units, dispenser=self._dispenser if dispenser is None else dispenser)

	def _fallback_dispenser(self):
		return UnitDispenser()

	def __call__(self, units, dispenser=None):
		dispenser = dispenser if dispenser is not None else self._dispenser
		if not isinstance(units, Units):
			units = dispenser(units)
		return self._new(self.value / units.scale(self.units), units, dispenser)

	def __repr__(self):
		return str(self)

	def __unicode__(self):
		return u"%s %s" % (self.value,  unicode(self.units))

	def __str__(self):
		return unicode(self).encode('utf-8')

	def __add__(self, other, reverse=False):
		if other == 0:
			return self._new(self.value, self.units)
		elif type(other) is tuple and len(other) == 2:
			other = self._new(*other)
		elif not isinstance(other, Quantity):
			other = self._new(other, None)
		if reverse:
			scale = self.units.scale(other.units)
			return self._new(scale * self.value + other.value, other.units)
		else:
			scale = other.units.scale(self.units)
			return self._new(self.value + scale * other.value, self.units)

	def __radd__(self, other):
		return self.__add__(other, reverse=True)

	def __sub__(self, other, reverse=False):
		if other == 0:
			return self._new(self.value, self.units)
		elif type(other) is tuple and len(other) == 2:
			other = self._new(*other)
		elif not isinstance(other, Quantity):
			other = self._new(other, None)
		if reverse:
			scale = self.units.scale(other.units)
			return self._new(-scale * self.value + other.value, other.units)
		else:
			scale = other.units.scale(self.units)
			return self._new(self.value - scale * other.value, self.units)

	def __rsub__(self, other):
		return self.__sub__(other, reverse=True)

	def __abs__(self):
		return self._new(abs(self.value), self.units)

	def __mul__(self, other):
		if type(other) is tuple and len(other) == 2:
			other = self._new(*other)
		try:
			units = self.units * other.units
			return self._new(self.value * other.value, units)
		except AttributeError:
			return self._new(self.value * other, self.units)

	def __rmul__(self, other):
		return self.__mul__(other)

	def __div__(self, other):
		if type(other) is tuple and len(other) == 2:
			other = self._new(*other)
		try:
			units = self.units / other.units
			return self._new(self.value / other.value, units)
		except AttributeError:
			return self._new(self.value / other, self.units)

	def __truediv__(self, other):
		return self.__div__(other)

	def __rdiv__(self, other):
		if type(other) is tuple and len(other) == 2:
			other = self._new(*other)
			return other / self
		return self._new(other / self.value, 1 / self.units)

	def __rtruediv__(self, other):
		return self.__rdiv__(other)

	def __pow__(self, other):
		return self._new(self.value ** other, self.units ** other)

	# Duplicate functionality (as in __cmp__) to allow for comparison with non Quantity objects
	def __eq__(self,other):
		if type(other) is tuple and len(other) == 2:
			other = self._new(*other)
		if isinstance(other, Quantity):
			scale = self.units.scale(other.units)
			if self.__truncate(self.value) == self.__truncate(other.value / scale):
				return True
		return False

	def __ne__(self,other):
		return not self.__eq__(other)

	def __cmp__(self, other):
		if type(other) is tuple and len(other) == 2:
			other = self._new(*other)
		if isinstance(other, Quantity):
			scale = self.units.scale(other.units)
			if self.__truncate(self.value) == self.__truncate(other.value / scale):
				return 0
			elif self.__truncate(self.value) > self.__truncate(other.value / scale):
				return 1
			return -1
		raise ValueError("Unknown comparison between Quantity and object of type %s." % (type(other)))

	def __truncate(self, value):
		if value == 0:
			return value
		return round(value, int(-math.floor(math.log(abs(value), 10)) + 10))

	def __rshift__(self, str_units):
		return self(str_units).value
