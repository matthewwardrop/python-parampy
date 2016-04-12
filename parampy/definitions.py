# coding=utf-8

import math

from .units import UnitDispenser, Unit
from .quantities import Quantity

class SIUnitDispenser(UnitDispenser):
	'''
	A subclass of :class:`UnitDispenser` which prepopulates the unit dispenser
	with SI units and some common other units. For a complete list of supported
	units, please see the "Supported Units" chapter of the python-parameters
	documentation.
	'''

	def init_prefixes(self):
		'''
		This method is called by the :class:`UnitDispenser` constructor, at which
		point this method populates the dispenser object with the SI prefixes. See
		the "Supported Units" chapter of the python-parameters documentation for
		a list of supported prefixes.
		'''
		self._prefixes = [
				("yotta", "Y", 1e24),
				("zepto", "Z", 1e21),
				("exa", "E", 1e18),
				("peta", "P", 1e15),
				("tera", "T", 1e12),
				("giga", "G", 1e9),
				("mega", "M", 1e6),
				("kilo", "k", 1e3),
				("milli", "m", 1e-3),
				("micro", (u"μ", "{mu}"), 1e-6),
				("nano", "n", 1e-9),
				("pico", "p", 1e-12),
				("femto", "f", 1e-15),
				("atto", "a", 1e-18),
				("zepto", "z", 1e-21),
				("yocto", "y", 1e-24)
			]

	def init_units(self):
		'''
		This method is called by the :class:`UnitDispenser` constructor, at which
		point this method populates the dispenser object with the SI units (and some
		other common units). See the "Supported Units" chapter of the
		python-parameters documentation for a list of supported units.
		'''

		# Fundamental SI units
		self \
			+ Unit(["constant", "non-dim", "1"], "", 1.0, prefixable=False) \
			+ Unit(["metre", "meter"], "m", 1.0).set_dimensions(length=1) \
			+ Unit("second", "s", 1.0).set_dimensions(time=1) \
			+ Unit("gram", "g", 1e-3).set_dimensions(mass=1) \
			+ Unit("ampere", "A", 1.0).set_dimensions(current=1) \
			+ Unit("kelvin", "K", 1.0).set_dimensions(temperature=1) \
			+ Unit("mole", "mol", 1.0).set_dimensions(substance=1) \
			+ Unit("candela", "cd", 1.0).set_dimensions(intensity=1) \
			+ Unit("dollar", "$", 1.0, prefixable=False).set_dimensions(currency=1) \
			+ Unit("radian", "rad", 1.0).set_dimensions(angle=1)
		self.basis(mass='kg')

		# Non-linear units
		self \
			+ Unit("decibel", "dB", 1.0)

		self.add_conversion_map("dB", "", lambda v: 10**(v/10.))
		self.add_conversion_map("", "dB", lambda v: 10*math.log(v,10))

		# Angular units
		self \
			+ Unit("degree", [u"°","deg"], 180./math.pi).set_dimensions(angle=1)
		self.add_scaling({'time':-1,'angle':1}, {'time':-1}, 1./2/math.pi)
		self.add_scaling({'angle':1}, {}, 1)

		# Scales
		self \
			+ Unit("mile", "mi", 1609.344).set_dimensions(length=1) \
			+ Unit("yard", "yd", 0.9144).set_dimensions(length=1) \
			+ Unit("foot", "ft", 0.3048, plural="feet").set_dimensions(length=1) \
			+ Unit("inch", "in", 0.0254, plural="inches").set_dimensions(length=1) \
			+ Unit(["centimetre", "centimeter"], "cm", 0.01).set_dimensions(length=1) \
			+ Unit("point", "pt", 2.54e-05).set_dimensions(length=1) \
			+ Unit("angstrom", u"Å", 1e-10).set_dimensions(length=1) \
			+ Unit("astronomical unit", "au", 149597870691.0).set_dimensions(length=1) \
			+ Unit("lightyear", "ly", 9460730472580800.).set_dimensions(length=1)

		# Time
		self \
			+ Unit("year", "year", 31557600.0, prefixable=False).set_dimensions(time=1) \
			+ Unit("month", "month", 2629800.0, prefixable=False).set_dimensions(time=1) \
			+ Unit("fortnight", "fortnight", 1209600.0, prefixable=False).set_dimensions(time=1) \
			+ Unit("week", "week", 604800.0, prefixable=False).set_dimensions(time=1) \
			+ Unit("day", "day", 86400.0, prefixable=False).set_dimensions(time=1) \
			+ Unit("hour", "hour", 3600., prefixable=False).set_dimensions(time=1) \
			+ Unit("minute", "min", 60., prefixable=False).set_dimensions(time=1) \
			+ Unit("hertz", "Hz", 1.).set_dimensions(time=-1)

		# Force
		self \
			+ Unit("newton", "N", 1.).set_dimensions(mass=1, length=1, time=-2)

		# Pressure
		self \
			+ Unit("atm", "atm", 101325.0).set_dimensions(mass=1, length=-1, time=-2) \
			+ Unit("bar", "bar", 100000.0).set_dimensions(mass=1, length=-1, time=-2) \
			+ Unit("pascal", "Pa", 1.).set_dimensions(mass=1, length=-1, time=-2) \
			+ Unit("mmHg", "mmHg", 101325. / 760).set_dimensions(mass=1, length=-1, time=-2) \
			+ Unit("psi", "psi", 6894.757).set_dimensions(mass=1, length=-1, time=-2)

		# Energy
		self \
			+ Unit("joule", "J", 1.).set_dimensions(mass=1, length=2, time=-2) \
			+ Unit("calorie", "cal", 4.1868).set_dimensions(mass=1, length=2, time=-2) \
			+ Unit("electronvolt", "eV", 1.602176487e-19).set_dimensions(mass=1, length=2, time=-2) \
			+ Unit("watt", "W", 1.).set_dimensions(mass=1, length=2, time=-3)

		# Electromagnetism
		self \
			+ Unit("coulomb", "C", 1.0).set_dimensions(current=1, time=1) \
			+ Unit("farad", "F", 1.0).set_dimensions(time=4, current=2, length=-2, mass=-1) \
			+ Unit("henry", "H", 1).set_dimensions(mass=1, length=2, time=-2, current=-2) \
			+ Unit("volt", "V", 1.).set_dimensions(mass=1, length=2, current=-1, time=-3) \
			+ Unit("ohm", u"Ω", 1.).set_dimensions(mass=1, length=2, time=-3, current=-2) \
			+ Unit("siemens", "mho", 1.).set_dimensions(mass=-1, length=-2, time=3, current=2) \
			+ Unit("tesla", 'T', 1.).set_dimensions(mass=1, current=-1, time=-2) \
			+ Unit("gauss", "G", 1e-4).set_dimensions(mass=1, current=-1, time=-2)

		# Volume
		self \
			+ Unit(["litre", "liter"], "L", .001).set_dimensions(length=3) \
			+ Unit("gallon", "gal", 4 * 473176473. / 125000000000).set_dimensions(length=3) \
			+ Unit("quart", "qt", 473176473. / 125000000000).set_dimensions(length=3) \
			+ Unit("weber", "Wb", 1.).set_dimensions(length=2, mass=1, time=-2, current=-1)

		# Temperature
		self \
			+ Unit("fahrenheit", [u"°F","degF"], 9./5).set_dimensions(temperature=1) \
			+ Unit("celsius", [u"°C","degC"], 1.).set_dimensions(temperature=1)

		self.add_conversion_map('fahrenheit','celsius',lambda f: (f - 32)*5./9, absolute=True)
		self.add_conversion_map('fahrenheit','kelvin',lambda f: (f + 459.67)*5./9, absolute=True)
		self.add_conversion_map('fahrenheit','celsius',lambda f: f*5./9, absolute=False)
		self.add_conversion_map('fahrenheit','kelvin',lambda f: f*5./9, absolute=False)

		self.add_conversion_map('celsius','fahrenheit',lambda c: c*9./5 + 32, absolute=True)
		self.add_conversion_map('celsius','kelvin',lambda c: c +  273.15, absolute=True)
		self.add_conversion_map('celsius','fahrenheit',lambda c: c*9./5, absolute=False)
		self.add_conversion_map('celsius','kelvin',lambda c: c, absolute=False)

		self.add_context("cm", hbar=1.05457173e-34)

		self.add_scaling({'mass':1,'length':2,'time':-2}, {'time':-1}, lambda hbar: 1./2/math.pi/hbar, context="cm")

class SIQuantity(Quantity):
	'''
	A subclass of :class:`Quantity` which has a fallback default dispenser of an
	:class:`SIUnitDispenser` rather than an empty :class:`UnitDispenser`. See
	documentation of :class:`Quantity` for more information.
	'''

	def _new(self, value, units, dispenser=None, absolute=False):
		return SIQuantity(value, units, dispenser=self.dispenser if dispenser is None else dispenser, absolute=absolute)

	def _fallback_dispenser(self):
		return SIUnitDispenser()
