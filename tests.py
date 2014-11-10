import timeit
import cProfile as profile
import numpy as np

from parameters import Parameters,SIDispenser,Quantity,SIQuantity,Unit, UnitsDispenser, Units, errors

print "Performance Tests"
print "-----------------"
print
print " - Simple Parameter Extraction"
x = 1e23
p=Parameters()
p(x=x)
q = {'x':x}
#p['x'] = (0,1e24)

def testP():
	return p('x')
def testP2():
	return p('x',x=1)
def testD():
	return q['x']
def testR():
	return x

def timer():
	time1 = timeit.timeit("testP()", setup="from __main__ import testP",number=100000)
	time2 = timeit.timeit("testD()", setup="from __main__ import testD",number=100000)
	time3 = timeit.timeit("testR()", setup="from __main__ import testR",number=100000)
	time4 = timeit.timeit("testP2()", setup="from __main__ import testP2",number=100000)
	print "p('x'):"
	print time1/time2, "times slower than dict at %f cf %f" % (time1,time2)
	print time1/time3, "times slower than raw at %f cf %f" % (time1,time3)
	print "p('x',x=1):"
	print time4/time2, "times slower than dict at %f cf %f" % (time1,time2)
	print time4/time3, "times slower than raw at %f cf %f" % (time1,time3)
timer()

profile.run('testP()',filename='pam_extract.pstats')

print
print " - Functional Evalution (y=x^2)"
p(y=lambda x: x**2)
o = p.optimise('x^2')
def testP():
	return p(o)
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


print "\n\n"
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

	def test_algebra(self):
		self.assertEqual( (SIQuantity(1,'m')**2 + SIQuantity(1,'nm')**2 ).value, 1+1e-18 )
		self.assertEqual( (SIQuantity(1,'m') + SIQuantity(1,'nm') ).value, 1+1e-9 )

	def test_zero(self):
		self.assertEqual( (SIQuantity(1,'m') + 0 ).value, 1 )
		self.assertEqual( (0 + SIQuantity(1,'m') ).value, 1 )

	def test_scaling(self):
		self.assertEqual( (2*SIQuantity(1,'m')).value, 2 )
		self.assertEqual( (SIQuantity(1,'m')/2.).value, 0.5 )

	def test_div(self):
		self.assertEqual( 2./SIQuantity(3,'m'), SIQuantity(2./3,'1/m') )

	def test_conversion(self):
		self.assertEqual( (SIQuantity(1,'m') + (1,'m')), SIQuantity(2,'m') )
		self.assertEqual( (SIQuantity(1,'m') - (1,'m')), SIQuantity(0,'m') )
		self.assertEqual( ((1,'m') + SIQuantity(1,'m')), SIQuantity(2,'m') )
		self.assertEqual( ((1,'m') - SIQuantity(1,'m')), SIQuantity(0,'m') )
		self.assertEqual( (SIQuantity(1,'m') * (1,'m')), SIQuantity(1,'m^2') )
		self.assertEqual( (SIQuantity(1,'m') / (1,'m')), SIQuantity(1,'') )
		self.assertEqual( ((1,'m') * SIQuantity(1,'m')), SIQuantity(1,'m^2') )
		self.assertEqual( ((1,'m') / SIQuantity(1,'m')), SIQuantity(1,'') )

class TestParameters(unittest.TestCase):

	def setUp(self):
		self.p = Parameters(default_scaled=False,constants=True)

	def test_create(self):
		self.p(x=1.)
		self.assertEqual( self.p.x, SIQuantity(1.) )

		self.p(x=(1,"nm"))
		self.assertEqual( self.p.x, SIQuantity(1,'nm') )

		self.p & {'x':'m'}
		self.assertEqual( self.p.x, SIQuantity(1e-9,'m') )

	def test_function(self):
		self.p(x=(2,'m'),y=(2,'m'),z=lambda x,y: x**2 + y**2)
		self.assertEqual( self.p.z , SIQuantity( 8., 'm^2') )

	def test_inverse(self):
		self.p(x=(2,'nm'),y=(2,'m'))
		self.p << {'z':lambda x,y,z=None: x**2 + y**2 if z is None else [2,3]}
		self.p(z=2)
		self.assertEqual( self.p.x , SIQuantity( 2 ,'m'))

	def test_inverse_quantity(self):
		self.p(x=(2,'nm'),y=(2,'m'))
		self.p << {'z':lambda x,y,_z=None: x**2 + y**2 if _z is None else [2,3]}
		self.assertEqual(self.p.z,self.p.x**2+self.p.y**2)

		self.p(z=10)
		self.assertEqual( self.p.x , SIQuantity( 2 ,'m'))

	def test_chaining(self):
		self.p(x=2,k=1)
		self.p << {
			'y':lambda k, y=None: k+SIQuantity(1) if y is None else y,
			'z':lambda x,y,z=None: x+y if z is None else [2,3]
			}
		self.p(z=1)
		self.assertEqual( self.p.x, SIQuantity(2.) )
		self.assertEqual( self.p.k, SIQuantity(3.) )
		self.assertEqual( self.p.y, SIQuantity(4.) )

	def test_nested(self):
		self.p(x=2,y=lambda x: x+SIQuantity(1), z=lambda x,y: x+y)
		self.assertEqual( self.p.z, SIQuantity(5.) )

	def test_scaling(self):
		self.p.scaling(length=(1,'nm'), time=(2,'s'))
		self.p(x=(1,"nm"))
		self.assertEqual( self.p._x , 1.0 )

		self.p(y=(0.5,"nm/s"))
		self.assertEqual( self.p._y, 1.0 )

	def test_override(self):
		self.p << {'x':2,'y':lambda x: x**2}
		self.assertEqual( self.p('y',x=4), SIQuantity(16) )

		self.p << {'x':(2,'m'),'y':(2,'m'),'z':lambda x,y,z=None: x**2 + y**2 if z is None else (2,3)}
		self.assertEqual( self.p('z',x=1,y=1) , SIQuantity( 2 ,'m^2'))

		self.p('x','y','z')

	def test_scaled(self):
		self.p & {'x':'nm'}
		self.p.scaling(length=(1,'nm'))
		self.p(x=1)
		self.assertEqual( self.p._x , 1.0 )
		self.assertEqual( self.p.x, SIQuantity (1,'nm') )

		self.assertEqual( self.p.scaling('length'), SIQuantity(1,'nm') )
		self.assertEqual( self.p.scaling('mass'), SIQuantity(1,'kg') )
		self.assertEqual( self.p.scaling('length','mass'), {'length': SIQuantity(1,'nm'), 'mass': SIQuantity(1,'kg')})

	def test_change_scaling(self):
		self.p.x = (1,'m')
		self.p & {'x':'nm'}
		self.assertEqual( self.p.x, SIQuantity(1,'m') )

	def test_scaled_inverse(self):
		self.p & {'x':'nm','y':'nm'}
		self.p.scaling(length=(1,'nm'))
		self.p(x=2,y=2,z=lambda x,y: x**2 + y**2)
		self.p(z=2)
		self.assertEqual( self.p._x , 2)

	def test_functional(self):
		self.p(x=1,y=2)
		self.assertEqual( self.p(lambda x : x**2), SIQuantity(1) )
		self.assertEqual( self.p(lambda _x : _x**2), 1 )
		self.assertEqual( self.p(lambda x,y : x**2 + y**2), SIQuantity(5) )
		self.assertEqual( self.p(lambda _x,_y : _x**2 + _y**2), 5 )

	def test_units(self):
		self.p.unit_add(names='testunit',abbr='TU',rel=1e7,dimensions={'length':1,'mass':1},prefixable=False)
		self.assertEqual( self.p('x',x=(1,'TU'))('kg*m') , SIQuantity(1e7,'kg*m') )

	def test_reserved(self):
		self.p.unit_add = (1,'ms')
		self.assertEqual( self.p('_unit_add'), 1e-3 )

	def test_conversion(self):
		self.assertEqual(SIQuantity(1.,'mT'), self.p.convert(1.0,'mT','mT'))
		self.assertEqual(SIQuantity(1e-3,'T'), self.p.convert(1.0,'mT','T'))
		self.assertRaises(errors.UnitConversionError, self.p.convert, 1.0, 'kg', 's')
		self.assertEqual(1e-3, self.p.convert(1.0,'mT'))
		self.assertEqual(SIQuantity(1e3,'mT'), self.p.convert(1.0,output='mT'))
		self.p.scaling(mass=(1,'g'))
		self.assertEqual(1.0, self.p.convert(1.0,'mT'))

	def test_symbolic(self):
		self.assertEqual(self.p('_x^2 + _y^2', x=1, y=2),5.0)

	def test_constants(self):
		self.assertEqual(self.p._c_h,6.62606957e-34)
		self.assertEqual(self.p.c_h,SIQuantity(6.62606957e-34,'J*s'))

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
		self.p.scaling(mass=(-1000,'kg'))
		self.assertEquals( self.p.asvalue(x=np.array([1,2,3])).tolist(),[-1000,-2000,-3000] )
		self.assertEquals( self.p.asvalue(x=np.array([1,2,3]),y=np.array([1,2,3]))['y'].tolist(),[1,2,3] )

	def test_bounds(self):
		self.p(x=(1,'J'))
		self.p['x'] = ( (1,'J'), None )
		self.assertRaises(errors.ParametersException,self.p,x=0)

		self.p(y=(2,'J'))
		self.p.set_bounds({'y': [ (0, 1), (3,4) ]})
		self.assertRaises(errors.ParameterOutsideBoundsError,self.p,'y')

	def test_ranges(self):
		self.assertEqual( self.p.range('_J_1',J_1=[0.1,0.2,0.4]), [0.1,0.2,0.4] )

		self.p(x=1)
		self.p << {'y':'_x^2'}
		self.assertEqual( np.round(self.p.range('_y',x=[0.1,0.2,0.3]),4).tolist(), [0.01,0.04,0.09] )

		self.assertEqual( self.p.range('_z',z=(1,'$'),k=[1,2,3,4]), [1,1,1,1] )

		self.assertEqual( self.p.range('_z',z=(1,"2*_x",4),x=2), [1,2,3,4])
		self.assertEqual( self.p.range('_z',z=((1,"m"),("2*_x","m"),4),x=2), [1,2,3,4])

	def test_passthrough(self):
		self.assertEqual( self.p(10.0), 10.0 )
		self.assertEqual( self.p( (10,'m') ), SIQuantity(10.0,'m') )
		self.assertEqual( self.p(SIQuantity(10.0,'m')), SIQuantity(10.0,'m') )

	def test_setattr(self):
		self.p.x = (1,'ms')
		self.assertEqual( self.p.x, SIQuantity(1,'ms') )

	def test_reset(self):
		self.p.y = 1
		self.p._y
		self.p.y = 2
		self.assertEqual( self.p('_y'), 2 )
		self.assertEqual( self.p._y, 2 )

	def test_recursion(self):

		def recurse():
			self.p << {'y': lambda z: z, 'z': lambda y: y} # mixed recursion

		self.assertRaises(errors.ParameterRecursionError,recurse)

	def test_context(self):
		self.p.x = 1
		with self.p:
			self.p.x = 2
			self.assertEqual(self.p._x,2)
		self.assertEqual(self.p._x,1)

	def test_complex(self):
		self.p.x = 1 + 2j

		self.assertEqual(self.p._x,1+2j)
		self.assertEqual(self.p('_x^2'),-3+4j)

	def test_range_advanced(self):
		self.p.k = 2

		self.assertEqual(self.p.range('_x',x=('-_k','_k',3)),[-2,0,2])
		self.assertEqual(self.p.range('_x',x=['_k','2*_k','_k/2'],k=[1,3,5]),[1,6,2.5])
		self.assertEqual(self.p.range('_x',x=['_k','2*_k','_k/2'],k=(1,3,3)),[1,4,1.5])

	def test_lambda_init(self):

		self.p.z = 2
		self.assertEqual( self.p('_x',x=(lambda _k:_k**2, '$'),k=2), 4)
		self.assertEqual( self.p('_x',x=(lambda _k:_k**2, '$'),k=lambda z:z), 4)


if __name__ == '__main__':
	unittest.main()
