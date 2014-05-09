# coding=utf-8

from .units import UnitsDispenser,Unit

class SIDispenser(UnitsDispenser):
	
	def init_prefixes(self):
		self._prefixes = [
		    ("yotta","Y",1e24),
		    ("zepto","Z",1e21),
		    ("exa","E",1e18),
		    ("peta","P",1e15),
		    ("tera","T",1e12),
		    ("giga","G",1e9),
		    ("mega","M",1e6),
		    ("kilo","k",1e3),
		    ("milli","m",1e-3),
		    ("micro","{mu}",1e-6),
		    ("nano","n",1e-9),
		    ("pico","p",1e-12),
		    ("femto","f",1e-15),
		    ("atto","a",1e-18),
		    ("zepto","z",1e-21),
		    ("yocto","y",1e-24)
	       ]
	
	def init_units(self):
		
		# Fundamental SI units
		self \
			+ Unit(["constant","non-dim","1"],"",1.0 ) \
			+ Unit(["metre","meter"],"m",1.0 ).set_dimensions(length=1) \
			+ Unit("second","s",1.0).set_dimensions(time=1) \
			+ Unit("gram","g",1e-3).set_dimensions(mass=1) \
			+ Unit("ampere","A",1.0).set_dimensions(current=1) \
			+ Unit("kelvin","K",1.0).set_dimensions(temperature=1) \
			+ Unit("mole","mol",1.0).set_dimensions(substance=1) \
			+ Unit("candela","cd",1.0).set_dimensions(intensity=1) \
			+ Unit("dollar","$",1.0).set_dimensions(currency=1)
		self.basis(mass='kg')
		
		# Scales
		self \
			+  Unit("angstrom",u"Å",1e-10).set_dimensions(length=1) \
			+  Unit("astronomical unit","au",149597870691.0).set_dimensions(length=1) \
			+  Unit("lightyear","ly",9460730472580800.).set_dimensions(length=1)

		#Imperial Scales
		self \
			+  Unit("mile","mi",201168./125).set_dimensions(length=1) \
			+  Unit("yard","yd", 0.9144).set_dimensions(length=1) \
			+  Unit("foot","ft",381./1250,plural="feet").set_dimensions(length=1) \
			+  Unit("inch","in",127./5000.,plural="inches").set_dimensions(length=1) \
			+  Unit("point","pt",1.27/5000.).set_dimensions(length=1) \
			+  Unit("mmHg","mmHg",101325./760).set_dimensions(mass=1,length=-1,time=-2) 

		# Time
		self \
			+  Unit("year","year",3944615652./125).set_dimensions(time=1) \
			+  Unit("day","day",86400.0).set_dimensions(time=1) \
			+  Unit("hour","h",3600.).set_dimensions(time=1) \
			+  Unit("minute","min",60.).set_dimensions(time=1) \
			+  Unit("hertz","Hz",1.).set_dimensions(time=-1)

		# Force
		self \
			+  Unit("newton","N",1.).set_dimensions(mass=1,length=1,time=-2)

		# Pressure
		self \
			+  Unit("atm","atm",101325.0).set_dimensions(mass=1,length=-1,time=-2) \
			+  Unit("bar","bar",100000.0).set_dimensions(mass=1,length=-1,time=-2) \
			+  Unit("pascal","Pa",1.).set_dimensions(mass=1,length=-1,time=-2) \
			+  Unit("psi","psi",6894.757).set_dimensions(mass=1,length=-1,time=-2)

		# Energy
		self \
			+  Unit("joule","J",1.).set_dimensions(mass=1,length=2,time=-2) \
			+  Unit("calorie","cal",4.1868).set_dimensions(mass=1,length=2,time=-2) \
			+  Unit("electronvolt","eV",1.602176487e-19).set_dimensions(mass=1,length=2,time=-2) \
			+  Unit("watt","W",1.).set_dimensions(mass=1,length=2,time=-3)

		# Electromagnetism
		self \
			+  Unit("coulomb","C",1.0).set_dimensions(current=1,time=1) \
			+  Unit("farad","F",1.0).set_dimensions(time=4,current=2,length=-2,mass=-1) \
			+  Unit("henry","H",1).set_dimensions(mass=1,length=2,time=-2,current=-2) \
			+  Unit("volt","V",1.).set_dimensions(mass=1,length=2,current=-1,time=-3) \
			+  Unit("ohm",u"Ω",1.).set_dimensions(mass=1,length=2,time=-3,current=-2) \
			+  Unit("siemens","mho",1.).set_dimensions(mass=-1,length=-2,time=3,current=2) \
			+  Unit("tesla",'T',1.).set_dimensions(mass=1,current=-1,time=-2) \
			+  Unit("gauss","G",1e-4).set_dimensions(mass=1,current=-1,time=-2)

		# Volume
		self \
			+  Unit(["litre","liter"],"L",.001).set_dimensions(length=3) \
			+  Unit("gallon","gal",4*473176473./125000000000).set_dimensions(length=3) \
			+  Unit("quart","qt",473176473./125000000000).set_dimensions(length=3) \
			+  Unit("weber","Wb",1.).set_dimensions(length=2,mass=1,time=-2,current=-1)

