# coding=utf-8

from units import UnitsDispenser

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
		self.add(["constant","non-dim"],"",1.0)
		self.add(["metre","meter"],"m",1.0,length=1)
		self.add("second","s",1.0,time=1)
		self.add("gram","g",1e-3,mass=1)
		self.basis(mass='kg')
		self.add("ampere","A",1.0,current=1)
		self.add("kelvin","K",1.0,temperature=1)
		self.add("mole","mol",1.0,substance=1)
		self.add("candela","cd",1.0,intensity=1)
		self.add("dollar","$",1.0,currency=1)

		# Scales
		self.add("angstrom",u"Å",1e-10,length=1)
		self.add("astronomical unit","au",149597870691.0,length=1)
		self.add("lightyear","ly",9460730472580800.,length=1)

		#Imperial Scales
		self.add("mile","mi",201168./125,length=1)
		self.add("yard","yd", 0.9144,length=1)
		self.add("foot","ft",381./1250,length=1,plural="feet")
		self.add("inch","in",127./5000.,length=1,plural="inches")
		self.add("point","pt",1.27/5000.,length=1)
		self.add("mmHg","mmHg",101325./760,mass=1,length=-1,time=-2)

		# Time
		self.add("year","year",3944615652./125,time=1)
		self.add("day","day",86400.0,time=1)
		self.add("hour","h",3600.,time=1)
		self.add("minute","min",60.,time=1)
		self.add("hertz","Hz",1.,time=-1)

		# Force
		self.add("newton","N",1.,mass=1,length=1,time=-2)

		# Pressure
		self.add("atm","atm",101325.0,mass=1,length=-1,time=-2)
		self.add("bar","bar",100000.0,mass=1,length=-1,time=-2)
		self.add("pascal","Pa",1.,mass=1,length=-1,time=-2)
		self.add("psi","psi",6894.757,mass=1,length=-1,time=-2)

		# Energy
		self.add("joule","J",1.,mass=1,length=2,time=-2)
		self.add("calorie","cal",4.1868,mass=1,length=2,time=-2)
		self.add("electronvolt","eV",1.602176487e-19,mass=1,length=2,time=-2)
		self.add("watt","W",1.,mass=1,length=2,time=-3)

		# Electromagnetism
		self.add("coulomb","C",1.0,current=1,time=1)
		self.add("farad","F",1.0,time=4,current=2,length=-2,mass=-1)
		self.add("henry","H",1,mass=1,length=2,time=-2,current=-2)
		self.add("volt","V",1.,mass=1,length=2,current=-1,time=-3)
		self.add("ohm",u"Ω",1.,mass=1,length=2,time=-3,current=-2)
		self.add("siemens","mho",1.,mass=-1,length=-2,time=3,current=2)
		self.add("tesla",'T',1.,mass=1,current=-1,time=-2)
		self.add("gauss","G",1e-4,mass=1,current=-1,time=-2)

		# Volume
		self.add(["litre","liter"],"L",.001,length=3)
		self.add("gallon","gal",4*473176473./125000000000,length=3)
		self.add("quart","qt",473176473./125000000000,length=3)
		self.add("weber","Wb",1.,length=2,mass=1,time=-2,current=-1)

