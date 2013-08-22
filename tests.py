import timeit
import cProfile as profile

from parameters import Parameters,SIDispenser,Quantity,SIQuantity,Unit, UnitsDispenser, Units, errors

'''
print "Performance Tests"
print "-----------------"
print
print " - Simple Parameter Extraction"
x = 123123124.214214124124
p=Parameters()
p(x=x)
q = {'x':x}

def testP():
	return p.x
def testD():
	return q['x']
def testR():
	return x

def timer():
	time1 = timeit.timeit("testP()", setup="from __main__ import testP",number=10000)
	time2 = timeit.timeit("testD()", setup="from __main__ import testD",number=10000)
	time3 = timeit.timeit("testR()", setup="from __main__ import testR",number=10000)
	print time1/time2, "times slower than dict at %f cf %f" % (time1,time2)
	print time1/time3, "times slower than raw at %f cf %f" % (time1,time3)
timer()

profile.run('testP()',filename='pam_extract.pstats')

print
print " - Functional Evalution (y=x^2)"
p(y=lambda x: x**2)

def testP():
	return p('x^2')
def testP2():
	return p('y')
def testD():
	return q['x']**2
def testR():
	return x**2

def timer():
	time1 = timeit.timeit("testP()", setup="from __main__ import testP",number=10000)
	time2 = timeit.timeit("testP2()", setup="from __main__ import testP2",number=10000)
	time3 = timeit.timeit("testD()", setup="from __main__ import testD",number=10000)
	time4 = timeit.timeit("testR()", setup="from __main__ import testR",number=10000)
	print "p('x^2'): %f (%f) times slower than dict (raw) at %f cf %f (%f)" % (time1/time3,time1/time4,time1,time3,time4)
	print "p('y'): %f (%f) times slower than dict (raw) at %f cf %f (%f)" % (time2/time3,time2/time4,time2,time3,time4)

timer()

profile.run('testP2()',filename='pam_functional.pstats')


print "\n\n"'''
print "Unit Tests"
print "-----------------"
###################### UNIT TESTS ##############################################
import unittest

class TestUnit(unittest.TestCase):
	
	def test_creation(self):
		unit = Unit('name','nm',rel=2.0,prefixable=False,plural='names').set_dimensions(length=1)
		self.assertEqual(unit.names,['name'])
		self.assertEqual(unit.dimensions,{'length':1})

class TestUnitsDispenser(unittest.TestCase):
	
	def setUp(self):
		self.ud = SIDispenser() # Initialising this already tests addition of units
	
	def test_get_units(self):
		self.assertEqual(str(self.ud('kg^2/s')),'kg^2/s')

class TestQuantity(unittest.TestCase):
	
	def setUp(self):
		pass
	
	def test_create(self):
		pass
	
class TestParameters(unittest.TestCase):

	def setUp(self):
		self.p = Parameters(default_scaled=False,constants=True)

	def test_create(self):
		self.p(x=1.)
		self.assertEqual( self.p.x, SIQuantity(1.) )
		
		self.p & {'x':'nm'}
		self.assertEqual( self.p.x, SIQuantity(1,'nm') )
		
		self.p(x=(1,"nm"))
		self.assertEqual( self.p.x, SIQuantity(1,'nm') )
	
	def test_function(self):
		self.p(x=(2,'m'),y=(2,'m'),z=lambda x,y: x**2 + y**2)
		self.assertEqual( self.p.z , SIQuantity( 8., 'm^2') )
		
	def test_inverse(self):
		self.p(x=(2,'nm'),y=(2,'m'))
		self.p << {'z':lambda x,y,z=None: x**2 + y**2 if z is None else (2,3)}
		self.p(z=2)
		self.assertEqual( self.p.x , SIQuantity( 2 ,'m'))
	
	def test_chaining(self):
		self.p(x=2,k=1)
		self.p << {
			'y':lambda k, y=None: k+SIQuantity(1) if y is None else y,
			'z':lambda x,y,z=None: x+y if z is None else (2,3)
			}
		self.p(z=1)
		self.assertEqual( self.p.x, SIQuantity(2.) ) 
		self.assertEqual( self.p.k, SIQuantity(3.) )
		self.assertEqual( self.p.y, SIQuantity(4.) )
	
	def test_nested(self):
		self.p(x=2,y=lambda x: x+SIQuantity(1), z=lambda x,y: x+y)
		self.assertEqual( self.p.z, SIQuantity(5.) ) 
	
	def test_scaling(self):
		self.p*{'length':(1,'nm'), 'time':(2,'s')}
		self.p(x=(1,"nm"))
		self.assertEqual( self.p._x , 1.0 )
		
		self.p(y=(0.5,"nm/s"))
		self.assertEqual( self.p._y, 1.0 )
	
	def test_override(self):
		self.p << {'x':2,'y':lambda x: x**2}
		self.assertEqual( self.p('y',x=4), SIQuantity(16) )
		
		self.p << {'x':(2,'m'),'y':(2,'m'),'z':lambda x,y,z=None: x**2 + y**2 if z is None else (2,3)}
		self.assertEqual( self.p('z',x=1,y=1) , SIQuantity( 2 ,'m^2'))
	
	def test_scaled(self):
		self.p & {'x':'nm'}
		self.p*{'length':(1,'nm')}
		self.p(x=1)
		self.assertEqual( self.p._x , 1.0 )
		self.assertEqual( self.p.x, SIQuantity (1,'nm') )
	
	def test_scaled_inverse(self):
		self.p & {'x':'nm','y':'nm'}
		self.p*{'length':(1,'nm')}
		self.p(x=2,y=2,z=lambda x,y: x**2 + y**2)
		self.p(_update=True,z=2)
		self.assertEqual( self.p._x , 2)
	
	def test_functional(self):
		self.p(x=1,y=2)
		self.assertEqual( self.p(lambda x : x**2), SIQuantity(1) )
		self.assertEqual( self.p(lambda _x : _x**2), 1 )
		self.assertEqual( self.p(lambda x,y : x**2 + y**2), SIQuantity(5) )
		self.assertEqual( self.p(lambda _x,_y : _x**2 + _y**2), 5 )
	
	def test_units(self):
		self.p + {'names':'testunit','abbr':'TU','rel':1e7,'dimensions':{'length':1,'mass':1},'prefixable':False}
		self.assertEqual( self.p('x',x=(1,'TU'))('kg*m') , SIQuantity(1e7,'kg*m') )
	
	def test_conversion(self):
		self.assertEqual(SIQuantity(1.,'mT'), self.p.convert(1.0,'mT','mT'))
		self.assertEqual(SIQuantity(1e-3,'T'), self.p.convert(1.0,'mT','T'))
		self.assertRaises(errors.UnitConversionError, self.p.convert, 1.0, 'kg', 's')
		self.assertEqual(1e-3, self.p.convert(1.0,'mT'))
		self.assertEqual(SIQuantity(1e3,'mT'), self.p.convert(1.0,output='mT'))
		self.p*{'mass':(1,'g')}
		self.assertEqual(1.0, self.p.convert(1.0,'mT'))
	
	def test_symbolic(self):
		self.assertEqual(self.p('_x^2 + _y^2', x=1, y=2),5.0)
	
	def test_unit_scaling(self):
		self.p * ({"mass":1,"length":2,"time":-2}, 2.0)
		self.assertEqual( self.p('_x',x=(1,'J')), 2.0 )
	
	def test_constants(self):
		self.assertEqual(self.p._h,6.62606957e-34)
		self.assertEqual(self.p.h,SIQuantity(6.62606957e-34,'J*s'))
	
	def test_bad_name(self):
		def bad():
			self.p << {'asd%WAD':1}
		self.assertRaises(errors.ParameterInvalidError, bad)
	
	def test_noninvertable_functions(self):
		self.p << {'J_1': lambda t: t**2}
		self.assertRaises(errors.ParameterNotInvertableError, self.p, J_1=1)
		self.assertEqual(self.p('_J_1',J_1=1),1.)

	def test_asvalue(self):
		self.p(x=(1,'J'))
		self.p * {'mass':(-1000,'kg')}
		import numpy as np
		self.assertEquals( self.p.asvalue(x=np.array([1,2,3])).tolist(),[-1000,-2000,-3000] )
		self.assertEquals( self.p.asvalue(x=np.array([1,2,3]),y=np.array([1,2,3]))['y'].tolist(),[1,2,3] )

if __name__ == '__main__':
    unittest.main()