Supported Units
===============

This section documents the units and prefixes supported by :python:`SIQuantity`,
:python:`SIUnitDispenser` or subclasses thereof.

Prefixes
~~~~~~~~

Except where otherwise noted by an \* in the unit lists shown below, all units
can be prefixed with the following prefixes:

.. tabularcolumns:: |r||c|c|c|c|c|c|c|c|

======================= ======= ======= ======= ======= ======= ======= ======= =======
Larger Prefixes         kilo    mega    giga    tera    peta    exa     zepto   yotta
======================= ======= ======= ======= ======= ======= ======= ======= =======
Abbreviation            k       M       G       T       P       E       Z       Y
Scaling (:math:`10^x`)  3       6       9       12      15      18      21      24
======================= ======= ======= ======= ======= ======= ======= ======= =======

.. tabularcolumns:: |r||c|c|c|c|c|c|c|c|

======================= ======= ======= ======= ======= ======= ======= ======= =======
Smaller Prefixes        milli   micro   nano    pico    femto   atto    zepto   yocto
======================= ======= ======= ======= ======= ======= ======= ======= =======
Abbreviation            m       {mu},μ  n       p       f       a       z       y
Scaling (:math:`10^x`)  -3      -6      -9      -12     -15     -18     -21     -24
======================= ======= ======= ======= ======= ======= ======= ======= =======


Units
~~~~~~~~

The following units are split into groups according to the domains in which they are
relevant. Units marked with an asterisk are not prefixable.

Fundamental Units
-----------------

.. tabularcolumns:: |c|c|c|

=============== =============== ===============
Unit Names      Abbreviations   Dimensions
=============== =============== ===============
constant        non-dim         \-
metre, meter    m               L
second          s               T
gram            g               M
ampere          A               I
kelvin          K               :math:`\Theta`
mole            mol             N
candela         cd              J
dollar*         $               $
=============== =============== ===============


Lengths
-------

.. tabularcolumns:: |c|c|c|

====================== =============== ================
Unit Names             Abbreviations   Dimensions
====================== =============== ================
mile                   mi              L
yard                   yd              L
foot                   ft              L
inch                   in              L
centimetre, centimeter cm              L
point                  pt              L
angstrom               Å               L
astronomical unit      au              L
lightyear              ly              L
====================== =============== ================


Volumes
-------

.. tabularcolumns:: |c|c|c|

================= =============== ================
Unit Names        Abbreviations   Dimensions
================= =============== ================
litre,liter       L               :math:`L^{3}`
gallon            gal             :math:`L^{3}`
quart             qt              :math:`L^{3}`
================= =============== ================


Times
-----

.. tabularcolumns:: |c|c|c|

================= =============== ================
Unit Names        Abbreviations   Dimensions
================= =============== ================
year*             \-              T
day*              \-              T
hour*             \-              T
minute*           min             T
hertz             Hz              :math:`T^{-1}`
================= =============== ================


Force & Pressure
----------------

.. tabularcolumns:: |c|c|c|

================= =============== =====================
Unit Names        Abbreviations   Dimensions
================= =============== =====================
newton            N               :math:`MLT^{-2}`
atm               \-              :math:`ML^{-1}T^{-2}`
bar               \-              :math:`ML^{-1}T^{-2}`
pascal            Pa              :math:`ML^{-1}T^{-2}`
mmHg              mmHg            :math:`ML^{-1}T^{-2}`
psi               \-              :math:`ML^{-1}T^{-2}`
================= =============== =====================


Energy & Power
--------------

.. tabularcolumns:: |c|c|c|

================= =============== =====================
Unit Names        Abbreviations   Dimensions
================= =============== =====================
joule             J               :math:`ML^{2}T^{-2}`
calorie           cal             :math:`ML^{2}T^{-2}`
electronvolt      eV              :math:`ML^{2}T^{-2}`
watt              W               :math:`ML^{2}T^{-3}`
================= =============== =====================


Electromagnetism
----------------

.. tabularcolumns:: |c|c|c|

================= =============== ==============================
Unit Names        Abbreviations   Dimensions
================= =============== ==============================
coulomb           C               :math:`IT`
farad             F               :math:`T^{4}I^{2}L^{-2}M^{-1}`
henry             H               :math:`ML^{2}T^{-2}I^{-2}`
volt              V               :math:`ML^{2}I^{-1}T^{-3}`
ohm               Ω               :math:`ML^{2}I^{-2}T^{-3}`
siemens           mho             :math:`M^{-1}L^{-2}T^{3}I^{2}`
tesla             T               :math:`MI^{-1}T^{-2}`
gauss             G               :math:`MI^{-1}T^{-2}`
weber             Wb              :math:`L^{2}MT^{-2}I^{-1}`
================= =============== ==============================
