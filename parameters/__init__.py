__author__ = 'Matthew Wardrop'
__author_email__ = 'mister dot <surname> at gmail'
__version__ = '1.2.1'

import pyximport; pyximport.install()

import numpy as np

from .quantities import Quantity,SIQuantity
from .units import UnitDispenser, Units, Unit
from .definitions import SIDispenser
from .parameters import Parameters, Bounds
