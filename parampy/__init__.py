__author__ = 'Matthew Wardrop'
__author_email__ = 'mister.wardrop@gmail.com'
__version__ = '2.1.1'

import pyximport; pyximport.install()

import numpy as np

from .quantities import Quantity
from .units import UnitDispenser, Units, Unit
from .definitions import SIUnitDispenser, SIQuantity
from .parameters import Parameters, Bounds
