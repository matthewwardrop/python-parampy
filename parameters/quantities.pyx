import math
import errors
from functools import total_ordering
import numpy as np

from .units import UnitsDispenser,Units
from .definitions import SIDispenser

@total_ordering
class Quantity(object):
	'''
	Quantity (value,units=None,dispenser=None)

	An object that represents a physical quantity; that is, one with both
	value and dimension. It is able to convert between different united
	representations; and keeps track of units in basic arithmetic.

	Parameters
	----------
	value : The value of the physical quantity in units of `units`.
	units : A representation of the units of the object; typically a string.
		See documentation of 'Units' for more information.
	dispenser : The unit dispenser object from which unit objects are drawn.

	Examples
	--------

	You can extract the value and units of a Quantity object separately by
	accessing the 'value' and 'units' attributes of the object. The value
	is returned as a float; and the units are returned as a Units object.
	>>> Quantity(1,'ms').value == 1 and str(Quantity(1,'ms')) == 'ms'
	returns True.

	There are only three methods that one might be interested to call on a
	Quantity object.

	The first one is about unit conversion:
	>>> Quantity(1,'m')('km')
	This will convert the representation from 1 m to 0.001 km.
	Note that if a conversion unit is supplied that has different dimensions
	than the original unit, an exception will be raised.

	The second one is about converting the units to those of the underlying
	basis.
	>> Quantity(1,'km').basis()
	This would output 1000 m if dispenser was an unmodified SIDispenser.

	The third is a quick way to convert a number into a dimensionless form:
	>> Quantity(1,'m') >> 'km'
	This would return 0.001 .

	Otherwise, Quantity objects behave as you might expect.
	Multiplication and division:
	>>> Quantity(1,'m') * Quantity(2,'s')
	is equivalent to: Quantity(2,'m*s')
	>>> Quantity(1,'m') / Quantity(2,'kg/m^2')
	is equivalent to: Quantity(2,'m^3/kg')

	Addition and subtraction:
	>>> Quantity(1,'m') + Quantity(2,'km') == Quantity(2.001,'km')
	returns True; and likewise for subtraction.
	If you attempt to add or subtract quantities which do not share the same
	units, an error is raised.
	'''

	def __init__(self,value,units=None,dispenser=None):
		if value is None:
			raise errors.QuantityValueError("A quantity's value must not be None.")
		if isinstance(value,(list,tuple)):
			value = np.array(value)
		self.value = value
		self._dispenser = dispenser if dispenser is not None else self._fallback_dispenser()
		if not isinstance(units,Units):
			self.units = self._dispenser(units)
		else:
			self.units = units

	def basis(self):
		return self(self.units.basis)

	def new(self, value, units, dispenser=None):
		return Quantity(value,units,dispenser=self._dispenser if dispenser is None else dispenser)

	def _fallback_dispenser(self):
		return UnitsDispenser()

	def __call__(self,units,dispenser=None):
		dispenser = dispenser if dispenser is not None else self._dispenser
		if not isinstance(units,Units):
			units = dispenser(units)
		return self.new(self.value/ units.scale(self.units),units, dispenser)

	def __repr__(self):
		return str(self.value) + " " + str(self.units)

	def __add__(self,other):
		if other == 0:
			return self.new(self.value,self.units)
		elif type(other) is tuple and len(other) == 2:
			other = self.new(*other)
		scale = other.units.scale(self.units)
		return self.new(self.value+scale*other.value,self.units)

	def __radd__(self,other):
		return self.__add__(other)

	def __sub__(self,other):
		if other == 0:
			return self.new(self.value,self.units)
		elif type(other) is tuple and len(other) == 2:
			other = self.new(*other)
		scale = other.units.scale(self.units)
		return self.new(self.value-scale*other.value,self.units)

	def __rsub__(self,other):
		if other == 0:
			return self.new(-self.value,self.units)
		elif type(other) is tuple and len(other) == 2:
			other = self.new(*other)
		scale = other.units.scale(self.units)
		return self.new(-self.value+scale*other.value,self.units)

	def __abs__(self):
		return self.new(abs(self.value),self.units)

	def __mul__(self,other):
		if type(other) is tuple and len(other) == 2:
			other = self.new(*other)
		try:
			units = self.units*other.units
			return self.new(self.value*other.value,units)
		except AttributeError:
			return self.new(self.value*other,self.units)

	def __rmul__(self,other):
		if type(other) is tuple and len(other) == 2:
			other = self.new(*other)
		try:
			units = self.units*other.units
			return self.new(self.value*other.value,units)
		except AttributeError:
			return self.new(self.value*other,self.units)

	def __div__(self,other):
		if type(other) is tuple and len(other) == 2:
			other = self.new(*other)
		try:
			units = self.units/other.units
			return self.new(self.value/other.value,units)
		except AttributeError:
			return self.new(self.value/other,self.units)

	def __truediv__(self,other):
		return self.__div__(other)

	def __rdiv__(self,other):
		if type(other) is tuple and len(other) == 2:
			other = self.new(*other)
			return other / self
		return self.new(other/self.value,1/self.units)

	def __rtruediv__(self,other):
		return self.__rdiv__(other)

	def __pow__(self,other):
		return self.new(self.value**other, self.units**other)

	def __eq__(self,other):
		if type(other) is tuple and len(other) == 2:
			other = self.new(*other)
		if isinstance(other,Quantity):
			scale = self.units.scale(other.units)
			if self.__truncate(self.value) == self.__truncate(other.value/scale):
				return True
			return False
		return False

	def __lt__(self,other):
		scale = self.units.scale(other.units)
		return self.value < other.value/scale

	def __truncate(self,value):
		if value == 0:
			return value
		return round(value,int(-math.floor(math.log(abs(value),10))+10))

	def __rshift__(self,str_units):
		return self(str_units).value


class SIQuantity(Quantity):

	def new(self, value, units, dispenser=None):
		return SIQuantity(value,units,dispenser=self._dispenser if dispenser is None else dispenser)

	def _fallback_dispenser(self):
		return SIDispenser()
