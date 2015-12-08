import math
import errors
import warnings
from functools import total_ordering
import numpy as np

from .units import UnitDispenser, Units
from .text import colour_text
from .utility.compat import UnicodeMixin

@total_ordering
class Quantity(UnicodeMixin):
	'''
	Quantity (value,units=None,absolute=False,dispenser=None)

	A Quantity object represents a physical quantity; that is, one with both
	a value and dimensions. It is able to convert between different united
	representations; and keeps track of units in basic arithmetic.

	:param value: The value of the physical quantity in units of 'units'. Can be any python object conforming to standard numeric operations.
	:type value: Numeric
	:param units: A representation of the units of the object. See documentation of 'Units' for more information.
	:type units: str or Units
	:param absolute: Whether this quantity represents an absolute quantity (a quantity with an absolute reference scale)
		 or a relative one (such as a temperature delta).
	:type absolute: bool
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

		.. note:: Instantiating a `UnitDispenser` instance will be the slowest part
			of instantiating a `Quantity`; so in circumstances where performance is required,
			providing an already instantiated `UnitDispenser` instance is a good idea.

	Accessing value and units separately:
		You can extract the value and units of a Quantity object separately by
		accessing the 'value' and 'units' attributes of the object.

		>>> SIQuantity(1,'ms').value
		1
		>>> SIQuantity(1,'ms').units
		ms

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

	def __init__(self, value, units=None, absolute=False, dispenser=None):
		if value is None:
			raise errors.QuantityValueError("A quantity's value must not be None.")
		if isinstance(value, (list, tuple)):
			value = np.array(value)

		self.dispenser = dispenser
		self.value = value
		self.units = units
		self.absolute = absolute

	@property
	def value(self):
		'''
		The value (or magnitude) of the quantity in the current units.

		You can update this value using:

		>>> quantity.value = <value>
		'''
		return self.__value
	@value.setter
	def value(self, value):
		self.__value = value

	@property
	def units(self):
		'''
		The units of the quantity.

		You can update the units (maintaining the current value) using:

		>>> quantity.units = <Units object or string representation>
		'''
		return self.__units
	@units.setter
	def units(self, units):
		if not isinstance(units, Units):
			self.__units = self.dispenser(units)
		else:
			self.__units = units

	@property
	def absolute(self):
		'''
		A boolean specifying whether this unit requires an absolute reference frame.
		For example, many temperature scales do.

		You can update this value using:

		>>> quantity.value = <value>
		'''
		return self.__absolute
	@absolute.setter
	def absolute(self, absolute):
		self.__absolute = absolute

	@property
	def dispenser(self):
		'''
		The `UnitDispenser` instance used to generate units from string representations.

		You can update this reference using:

		>>> quantity.dispenser = <UnitDispenser instance>
		'''
		return self.__dispenser
	@dispenser.setter
	def dispenser(self, dispenser):
		if dispenser is not None and not isinstance(dispenser, UnitDispenser):
			raise ValueError("Quantity objects require a `UnitDispenser` instance.")
		self.__dispenser = dispenser if dispenser is not None else self._fallback_dispenser()

	def basis(self):
		'''
		basis()

		:returns: Quantity object with current value expressed in the basis units of the UnitDispenser.

		For example, for the :class:`SIUnitDispenser`:

		>>> SIQuantity(1,'J').basis()
		1.0 kg*m^2/s^2
		'''
		return self(self.units.basis())

	def _new(self, value, units, dispenser=None, absolute=False):
		return Quantity(value, units, dispenser=self.dispenser if dispenser is None else dispenser, absolute=absolute)

	def _fallback_dispenser(self):
		return UnitDispenser()

	def __call__(self, units, dispenser=None, context=False):
		dispenser = dispenser if dispenser is not None else self.dispenser
		if not isinstance(units, Units):
			units = dispenser(units)
		try:
			return self._new(dispenser.conversion_map(self.units, units, context=context, absolute=self.absolute)(self.value), units, dispenser, absolute=self.absolute)
		except:
			return self._new(self.value * self.units.scale(units, context=context, value=self.value), units, dispenser, absolute=self.absolute)

	def __repr__(self):
		return str(self)

	def __unicode__(self):
		return u"%s %s" % (self.value,  unicode(self.units)) + (u" (abs)" if self.absolute else u"")

	# Arithmetic
	def __add__(self, other, reverse=False):
		if other == 0:
			return self._new(self.value, self.units)
		elif type(other) is tuple and len(other) == 2:
			other = self._new(*other)
		elif isinstance(other, Units):
			raise ValueError("Invalid operation")
		elif not isinstance(other, Quantity):
			other = self._new(other, None)

		abs = self.absolute and not other.absolute or not self.absolute and other.absolute
		if reverse:
			scale = self.units.scale(other.units)
			return self._new(scale * self.value + other.value, other.units, absolute=abs)
		else:
			scale = other.units.scale(self.units)
			return self._new(self.value + scale * other.value, self.units, absolute=abs)

	def __radd__(self, other):
		return self.__add__(other, reverse=True)

	def __sub__(self, other, reverse=False):
		if other == 0:
			return self._new(self.value, self.units)
		elif type(other) is tuple and len(other) == 2:
			other = self._new(*other)
		elif isinstance(other, Units):
			raise ValueError("Invalid operation")
		elif not isinstance(other, Quantity):
			other = self._new(other, None)

		abs = self.absolute and not other.absolute or not self.absolute and other.absolute
		if reverse:
			scale = self.units.scale(other.units)
			return self._new(-scale * self.value + other.value, other.units, absolute=abs)
		else:
			scale = other.units.scale(self.units)
			return self._new(self.value - scale * other.value, self.units, absolute=abs)

	def __rsub__(self, other):
		return self.__sub__(other, reverse=True)

	def __abs__(self):
		return self._new(abs(self.value), self.units)

	def __mul__(self, other):
		if type(other) is tuple and len(other) == 2:
			other = self._new(*other)
		elif isinstance(other, Units):
			other = 1.0 * other
		try:
			abs = self.absolute and (self.units.dimensions == {} or other.units.dimensions == {})
			units = self.units * other.units
			return self._new(self.value * other.value, units, absolute=abs)
		except AttributeError:
			return self._new(self.value * other, self.units, absolute=self.absolute)

	def __rmul__(self, other):
		return self.__mul__(other)

	def __div__(self, other):
		if type(other) is tuple and len(other) == 2:
			other = self._new(*other)
		elif isinstance(other, Units):
			other = 1.0 * other

		if isinstance(other, Quantity):
			if self.absolute or other.absolute:
				raise ValueError("Cannot divide absolute quantities.")
			absolute = self.absolute and (self.units.dimensions == {} or other.units.dimensions == {})
			units = self.units / other.units
			return self._new(self.value / other.value, units, absolute=absolute)

		return self._new(self.value / other, self.units, absolute=self.absolute)

	def __truediv__(self, other):
		return self.__div__(other)

	def __rdiv__(self, other):
		if type(other) is tuple and len(other) == 2:
			other = self._new(*other)
			return other / self
		elif isinstance(other, Units):
			other = 1.0 * other
			return other / self
		return self._new(other / self.value, 1 / self.units, absolute=self.absolute)

	def __rtruediv__(self, other):
		return self.__rdiv__(other)

	def __pow__(self, other):
		if isinstance(other, Quantity):
			other = other("").value
		return self._new(self.value ** other, self.units ** other)

	# Duplicate functionality (as in __cmp__) to allow for comparison with non Quantity objects
	def __eq__(self,other):
		if type(other) is tuple and len(other) == 2:
			other = self._new(*other)
		if isinstance(other, Quantity):
			scale = self.units.scale(other.units)
			if self.__truncate(self.value) == self.__truncate(other.value / scale) and self.absolute==other.absolute:
				return True
		return False

	def __ne__(self,other):
		return not self.__eq__(other)
	
	def __lt__(self,other): # Python 3 and newer ignore __cmp__
		return self.__cmp__(other) == -1

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

	# numpy compatibility

	__numpy_units_in = {
			# Trigonometry
			'sin': 'rad', 'cos': 'rad', 'tan': 'rad',
			'sinh': 'rad', 'cosh': 'rad', 'tanh': 'rad',
			'arcsin': '', 'arccos': '', 'arctan': '',
			'arcsinh': '', 'arccosh': '', 'arctanh': '',
			# Common functions
			'exp': '', 'expm1': '', 'expm2': '',
			'log': '', 'log10': '', 'log1p': '', 'log2': '',
			# Others
			'radians': 'deg', 'degrees': 'rad',
			'deg2rad': 'deg', 'rad2deg': 'rad',
			'logaddexp': '', 'logaddexp2': ''
		}

	__numpy_units_out = {
			# Trigonometry
			'sin': '', 'cos': '', 'tan': '',
			'sinh': '', 'cosh': '', 'tanh': '',
			'arcsin': 'rad', 'arccos': 'rad', 'arctan': 'rad',
			'arcsinh': 'rad', 'arccosh': 'rad', 'arctanh': 'rad',
			'arctan2': 'rad',
			# Others
			'radians': 'rad', 'degrees': 'deg',
			'deg2rad': 'rad', 'rad2deg': 'deg'
		}

	__numpy_units_power = {
			'sqrt': 0.5, 'square': 2, 'reciprocal': -1
		}

	__numpy_units_whatever = [
			'remainder'
	]

	__numpy_ufuncs = tuple(__numpy_units_in.keys()) + tuple(__numpy_units_out.keys()) +\
						tuple(__numpy_units_power.keys()) + tuple(__numpy_units_whatever)

	__array_priority__ = 1000

	def __getattr__(self, attr):
		if attr.startswith('__array_'):
			return getattr(np.asarray(self.value), attr)
		return object.__getattribute__(self, attr)

	def __array_prepare__(self, array, context=None):
		
		ufunc, objs, domain = context

		if ufunc.__name__ in self.__numpy_ufuncs and domain == 0:
			# Cannot deal with more than one ufunc at a time
			try:
				if self.__handling:
					raise Exception('Cannot handle nested ufuncs.')
			except:
				pass

			self.__handling = context

		return array

	def __array_wrap__(self, array, context=None):

		try:
			ufunc, objs, domain = context

			if ufunc.__name__ not in self.__numpy_ufuncs:
				warnings.warn("ufunc '%s' not explicitly understood. Attempting to apply anyway." % ufunc.__name__)

			if ufunc.__name__ in self.__numpy_units_in:
				objs = list(map(lambda x: x(self.__numpy_units_in[ufunc.__name__] if isinstance(x, Quantity) else x), objs))

			rv = ufunc(*[v.value if isinstance(v,Quantity) else v for v in objs])

			out_units = self.__dispenser(self.__numpy_units_out.get(ufunc.__name__, objs[0].units))
			out_units **= self.__numpy_units_power.get(ufunc.__name__, 1)

			r =  self._new(rv, self.__numpy_units_out.get(ufunc.__name__, out_units))

			return r
		except Exception as e:
			raise e
		finally:
			self.__handling = None

	def __long__(self):
		return long(self("").value)

	def __int__(self):
		return int(self("").value)

	def __float__(self):
		return float(self("").value)

	def __complex__(self):
		return complex(self("").value)
