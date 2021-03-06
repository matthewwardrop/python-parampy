API Documentation
=================

In this section, documentation is provided at a per-method level, allowing you
to write easily write scripts and problems which conform to the API. Future updates
with same major version should maintain backwards compatibility with this API.
If you find a problem or inconsistency in this documentation, that is a bug; and
the author would like to know about it.

The ordering of the API is from most often used to least often used classes
(for an expected average user); and so we begin with the :class:`Parameters` class,
then the :class:`Quantity` class, before moving to less used and more foundational
classes. Not documented here are classes and methods which the author deems to be for
internal use only.

The Parameters Class
--------------------

.. autoclass:: parampy.parameters.Parameters
    :members:
    :undoc-members:
    :show-inheritance:

.. autoclass:: parampy.parameters.Bounds
    :members:
    :undoc-members:
    :show-inheritance:

The Quantity Class
------------------

.. autoclass:: parampy.quantities.Quantity
    :members:
    :undoc-members:
    :show-inheritance:

.. autoclass:: parampy.definitions.SIQuantity
    :members:
    :undoc-members:
    :show-inheritance:

The Units Module
----------------

.. automodule:: parampy.units
    :members:
    :undoc-members:
    :show-inheritance:

.. autoclass:: parampy.definitions.SIUnitDispenser
    :members:
    :undoc-members:
    :show-inheritance:


Exceptions
----------

.. automodule:: parampy.errors
    :members:
    :undoc-members:
    :show-inheritance:


Useful Utility Classes
----------------------

.. autoclass:: parampy.iteration.RangesIterator
    :members:
    :undoc-members:
    :show-inheritance:
