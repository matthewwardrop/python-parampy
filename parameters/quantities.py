from units import UnitsDispenser,Units
from definitions import SIDispenser
import math

class Quantity(object):
	
	def __init__(self,value,units=None,dispenser=None):
		if value is None:
			raise ValueError
		self.value = value
		self._dispenser = dispenser if dispenser is not None else self._fallback_dispenser()
		if not isinstance(units,Units):
			self.units = self._dispenser.get(units)
		else:
			self.units = units
	
	def toSI(self):
		return self(self.units.basis)
	
	def new(self, value, units, dispenser=None):
		return Quantity(value,units,dispenser=self._dispenser if dispenser is None else dispenser)
	
	def _fallback_dispenser(self):
		return UnitsDispenser()
	
	def __call__(self,units,dispenser=None):
		dispenser = dispenser if dispenser is not None else self._dispenser
		if not isinstance(units,Units):
			units = dispenser.get(units)
		return self.new(self.value/ units.scale(self.units),units, dispenser)
	
	def __repr__(self):
		return str(self.value) + " " + str(self.units)

	def __add__(self,other):
		scale = other.units.scale(self.units)
		return self.new(self.value+scale*other.value,self.units)
	
	def __sub__(self,other):
		scale = other.units.scale(self.units)
		return self.new(self.value-scale*other.value,self.units)
	
	def __rsub__(self,other):
		scale = other.units.scale(self.units)
		return self.new(-self.value+scale*other.value,self.units)
	
	def __mul__(self,other):
		units = self.units*other.units
		return self.new(self.value*other.value,units)
	
	def __div__(self,other):
		units = self.units/other.units
		return self.new(self.value/other.value,units)
	
	def __pow__(self,other):
		return self.new(self.value**other, self.units**other)
	
	def __eq__(self,other):
		try:
			scale = self.units.scale(other.units)
			if self.__truncate(self.value) == self.__truncate(other.value/scale):
				return True
			return False
		except:
			return False
	
	def __truncate(self,value):
		return round(value,int(-math.floor(math.log(abs(value),10))+10))
	
	def __rshift__(self,str_units):
		return self(str_units).value
		

class SIQuantity(Quantity):
	
	def new(self, value, units, dispenser=None):
		return SIQuantity(value,units,dispenser=self._dispenser if dispenser is None else dispenser)
	
	def _fallback_dispenser(self):
		return SIDispenser()


'''	
	def fromStored(self,value,unit=None,stored=None):
		value *= self.getScalingForUnit(unit)
		if stored is None:
			stored = WorkingUnit.fromString(unit,dispensers=[self.custom_units]).getSIWorkingUnit()
		return Quantity(value,stored,dispensers=[self.custom_units])(unit,dispensers=[self.custom_units])
	
	def toStored(self,value,unit=None,stored=None):
		
		if isinstance(value,Quantity):
			if stored is not None:
				return value(stored,dispensers=[self.custom_units]).value/self.getScalingForUnit(value.units)
			return value.toSI().value/self.getScalingForUnit(value.units)
		
		q = Quantity(value,unit,dispensers=[self.custom_units])
		if stored is not None:
			return q(stored,dispensers=[self.custom_units]).value/self.getScalingForUnit(unit)
		return q.toSI().value/self.getScalingForUnit(unit)
	
	def convert(self,quantity,input=None,output=None):
		if isinstance(quantity,(np.ndarray,list)):
			scaling = self.convert(1.,input=input,output=output)
			return np.array(quantity)*scaling
		
		if isinstance(quantity,tuple):
			input = quantity[1]
			quantity = quantity[0]
		
		if input == output and input == None:
			return quantity
		
		if input is not None and output is None:
			return self.toStored(quantity,unit=input)
		
		if input is None and output is not None:
			return self.fromStored(quantity,unit=output).value
		
		return Quantity(quantity, input)(output).value'''
