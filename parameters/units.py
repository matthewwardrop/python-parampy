
from fractions import Fraction

class Unit(object):
	'''
	The fundamental unit object.
	'''
	
	def __init__(self,names,abbr=None,rel=1.0,prefixable=True,plural=None,**dimensions):
		self.names = names if isinstance(names,(tuple,list)) else [names]
		self.abbr = abbr
		self.plural = plural
		
		self.rel = rel
		self.prefixable = prefixable
		
		self.dimensions = dimensions
		
	def __repr__(self):
		return self.names[0]

class UnitsDispenser(object):
	
	def __init__(self):
		self._dimensions = {}
		self._units = {}
		self._prefixes = []
		
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
	
	def add(self,*args,**kwargs):
		unit = Unit(*args,**kwargs)
		
		for name in unit.names:
			self._units[name] = unit
		if unit.abbr != None:
			self._units[unit.abbr] = unit
		
		for dimension in unit.dimensions:
			if dimension not in self._dimensions:
				self._dimensions[dimension] = unit
		
		if unit.prefixable:
			for prefix in self._prefixes:
				self.add(
					names="%s%s" % (prefix[0],unit.names[0]),
					abbr="%s%s" % (prefix[1],unit.abbr) if unit.abbr is not None else None,
					plural="%s%s" % (prefix[0],unit.plural) if unit.plural is not None else None,
					rel=unit.rel*prefix[2],
					prefixable=False,
					**unit.dimensions)
	
	def list(self):
		return self._units.keys()
	
	def has(self,identifier):
		return self._units.has_key(identifier)
	
	def get_unit(self,identifier):
		return self._units[identifier]
	
	def basis(self,**kwargs):
		if not kwargs:
			return self._dimensions
		
		for key,val in kwargs.items():
			unit = self.get_unit(val)
			if unit.dimensions == {key:1}:
				self._dimensions[key] = unit
			else:
				print "Invalid unit (%s) for dimension (%s)" % (unit,key)
	@property
	def dimensions(self):
		return self._dimensions.keys()
	
	############# UNITS GENERATION #########################################
	
	def get(self,units):
		return Units(units,dispenser=self)
	

class Units(object):
	'''
	The object describing all possible arrangements of Unit objects.
	'''
	
	def __init__(self,units=None,dispenser=None):
		self.__dispenser = dispenser
		self.__units = self.__process_units(units)
	
	def __get_unit(self,unit):
		return self.__dispenser.get_unit(unit)
	
	def __process_units(self,units):
		
		if units is None:
			return {}
		
		elif isinstance(units,Units):
			return units.units.copy()
		
		elif isinstance(units,Unit):
			return {units:1}
		
		elif isinstance(units,dict):
			return units
		
		elif isinstance(units,str):
			
			d = {}
			items = units.split("/")
			numerator = items[0].split("*")
			denominator = items[1:]
	
			for item in numerator:
				info = item.split('^')
				subunit = self.__get_unit(info[0])
				if len(info) == 1:
					d[subunit] = d.get(subunit,0) + 1
				else:
					d[subunit] = d.get(subunit,0) + Fraction(info[1])
		
			for item in denominator:
				info = item.split('^')
				subunit = self.__get_unit(info[0])
				if len(info) == 1:
					d[subunit] = d.get(subunit,0) - 1
				else:
					d[subunit] = d.get(subunit,0) - Fraction(info[1])
		
			return d
			
		raise ValueError, "Unrecognised unit description %s" % units
	
	def __repr__(self):
		output = []
		
		items = sorted(self.__units.items())
		
		if self.dimensions == {}:
			return "units"
		
		for unit,power in items:
			if power > 0:
				if power != 1:
					output.append( "%s^%s" % (unit.abbr,power) )
				else:
					output.append( unit.abbr )
		output = "*".join(output)
		
		for unit,power in items:
			if power < 0:
				if power != -1:
					output += "/%s^%s" % (unit.abbr,abs(power))
				else:
					output += "/%s" % unit.abbr
		return output
	
	def scale(self,scale):
		'''
		Returns a float comparing the current units to the provided units.
		'''
		
		if isinstance(scale,str):
			scale = self.__dispenser.get(scale)
		
		dims = self.dimensions
		dims_other = scale.dimensions
		
		if len(set(dims.items()) & set(dims_other.items())) < max(len(dims),len(dims_other)):
			raise RuntimeError, "Invalid conversion. Units do not match."
		
		return self.rel / scale.rel
	
	@property
	def dimensions(self):
		dimensions = {}
		for unit,power in self.__units.items():
			for key,order in unit.dimensions.items():
				dimensions[key] = dimensions.get(key,0) + power*order
		for key,value in list(dimensions.items()):
			if value == 0:
				del dimensions[key]
		return dimensions
	
	@property
	def rel(self):
		'''
		Return the relative size of this unit (compared to other units from the same unit dispenser)
		'''
		
		rel = 1.
		for unit,power in self.__units.items():
			rel *= unit.rel**power
		return rel
		
	@property
	def basis(self):
		dimensionString = ""
		dimensionMap = self.__dispenser.basis()
		dimensions = self.dimensions
		
		for dimension in self.dimensions:
			if dimensions[dimension] != 0:
				dimensionString += "*%s^%f"%(dimensionMap[dimension].abbr if dimensionMap[dimension].abbr is not None else dimensionMap[dimension],float(dimensions[dimension]))
		
		return Unit(dimensionString[1:],dispenser=self.__dispenser)
	
	@property
	def units(self):
		return self.__units
	
	########### UNIT OPERATIONS ############################################
	
	def copy(self):
		return Units(self.__units.copy(),self.__dispenser)
	
	def mulUnit(self,unit,power=1):
		if unit in self.units:
			self.units[unit] += power
		else:
			self.units[unit] = power
		if self.units.get(unit,0) == 0:
			del self.units[unit]
		
	def divUnit(self,unit,power=1):
		if unit in self.units:
			self.units[unit] -= power
		else:
			self.units[unit] = -power
		if self.units.get(unit,0) == 0:
			del self.units[unit]
	
	def __mul__(self,other):
		newUnit = self.copy()
		for unit in other.units:
			newUnit.mulUnit(unit,other.units[unit])
		return newUnit
	
	def __div__(self,other):
		newUnit = self.copy()
		for unit in other.units:
			newUnit.divUnit(unit,other.units[unit])
		return newUnit
	
	def __pow__(self,other):
		newUnit = self.copy()
		for unit in newUnit.units:
			newUnit.units[unit] *= other
		return newUnit
	
	def __eq__(self,other):
		if str(self) == str(other):
			return True
		return False

################# UNIT TESTS ###################################################
import unittest

class TestUnit(unittest.TestCase):

	def setUp(self):
		self.p = Parameters()

	def test_create(self):
		pass
	
	def test_multiply(self):
		pass
		
if __name__ == '__main__':
	unittest.main()
