__author__ = 'Matthew Wardrop'
__author_email__ = 'mister dot <surname> at gmail'
__version__ = '1.3.0 RC'

import pyximport; pyximport.install()

import numpy as np

from .quantities import Quantity
from .units import UnitDispenser, Units, Unit
from .definitions import SIUnitDispenser, SIQuantity
from .parameters import Parameters, Bounds
