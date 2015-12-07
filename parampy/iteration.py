import sys
import threading
import resource
import datetime
import types

import numpy as np


class RangesIterator(object):
	'''
	RangesIterator(parameters, ranges, params={}, masks=None, function=None, function_args=(), function_kwargs={}, nprocs=None, distributed=False, ranges_eval=None, progress=True)

	:class:`RangesIterator` is a python iterable object, which allows one to easily
	iterate over a potentially multidimensional space of parameters. It also has
	inbuilt multithreading 	support which is used when a function is supplied in order
	to fully take advantage of the available computational resources.

	:param parameters: A reference to a Parameters instance.
	:type parameters: Parameters
	:param ranges: The ranges to iterate over.
	:type ranges: dict or list of dict
	:param params: A background context of parameters upon which the ranges should be superimposed.
	:type params: dict
	:param masks: A list of boolean functions which indicate when a particular index should be computed.
	:type masks: list of callable objects
	:param function: An (optional) function to call for every resulting parameter configuration.
	:type function: callable
	:param function_args: An (optional) tuple/list of args to pass to the above function at every call.
	:type function_args: tuple or list
	:param function_kwargs: An (optional) dictionary of kwargs to pass to the above function at every call.
	:type function_kwargs: dict
	:param nprocs: The number of processes to spawn at any one time (for multithreading support).
	:type nprocs: None or int
	:param distributed: `False` or `None` if distributed computing using dispynode servers is NOT to be used,
		and `True` or a dictionary of dispy.JobCluster parameters otherwise.
	:type distributed: NoneType, bool or dict
	:param ranges_eval: An (optional) previously computed ranges_eval to use in this enumeration.
	:type ranges_eval: numpy.ndarray
	:param progress: `True` if progress should be shown, and `False` otherwise. This can also
		be a callable object taking arguments `total`, `completed` and `start_time`, which
		are the total number of indices to compute, the number completed computations,
		and the start time computed using `datetime.datetime.now()`.
	:type progress: bool or callable

	Constructing a RangesIterator instance:
		In its simplest form, initialising a :class:`RangesIterator` looks like:

		>>> RangesIterator(p, ranges)

		Where *p* is a Parameters instance, and *ranges* is a valid specification
		of the ranges to be iterated over.

	Valid ranges specification:
		:python:`ranges` can be any valid range specification (as defined in
		:func:`Parameters.range`), or any list of valid range specifications.
		If a list of specifications is provided, then the cartesian product of
		range specifications is taken. For example:

		>>> ranges = [{'x':(0,10,11)},{'y':(0,10,11)}]

		If passed to RangesIterator, this will lead to iteration over the integer
		values of x in [0,10], and then for each x, to iterate over the integer values of
		y in [0,10]; forming the cartesian product [0,10]x[0,10].

		Remember that multiple parameters can be set at once, so that the following
		is also valid:
		>>> ranges = [{'x':(0,10,11),'k':(1,2,11)},{'y':(0,10,11)}]

	Iterating over a RangesIterator instance:
		To iterate over the possible parameter configurations, you use the regular
		iteration sytax:

		>>> for result in iterator:
				# Do something here

		In each iteration of the above loop, result will be a two-tuple of the indices of
		the current iteration in the cartesian product and one of the following:

		- If :func:`function` is not specified, then a dictionary of the parameters (including, except where overwritten, those in :python:`params`) corresponding to the cartesian indices.
		- If :func:`function` is specified, the value of the function evaluated in the parameter context, and with the kwargs arguments in :python:`function_kwargs`.

	Specifying a function to be evaluated:
		If specified, the :func:`function` value must be a callable type, such as a *function* or
		*instancemethod* (or any object implementing :func:`__call__`). The function must take at least the keyword value of
		:python:`params`. The following are examples of valid specifications:

		>>> def test(params):
				pass
		>>> RangesIterator(..., function=test, ...)

		>>> class Test(object):
				def test(self,params):
					pass
		>>> RangesIterator(..., function=Test().test, ...)

		>>> RangesIterator(..., function=lambda params: None, ...)

		The function can return any type, which will then be returned to you via
		the iteration process, as specified above.

		If :python:`function_kwargs` is specified, then the function provided
		will be evaluated with the additional kwargs present in that dictionary.

	Multithreading:
		By default, if :python:`function` is provided, :python:`RangesIterator`
		will spawn up to *N* parallel subprocesses to evaluate the function in different
		parameter contexts (where *N* is detailed below). If this is undesired, because your function is
		not threadsafe or for other reasons, you can specify :python:`nprocs` as
		a *0* or a *1*; in which case multithreading is disabled.

		Otherwise, :python:`nprocs` is to be the number of processes to use (with a default
		value of the number of processors of the machine). If specified as a negative
		number, then the iteration process will use that many fewer than the total number
		of processors on your machine.

	Distributed Computing:
		It is possible to have `RangesIterator` distribute tasks to any available dispynode
		servers. To enable this (which takes precedence over the above multithreading), simply
		set `distributed` to `True` or a dictionary of arguments to pass on to `dispy.JobCluster`.

	Masking:
		If you do not want the parameters or evaluated function at all possible
		cartesian products of the input ranges, then it is possible to use
		boolean masking functions. This is useful, for example, when wanting continue
		a previously started sweep.

		Masks should be callable objects with a signature of:
		:code:`<mask_name>(indices, ranges=None, params={})`

		For example:

		>>> def deny_mask(indices, ranges=None, params={}):
				return False # Deny all indices.

		At runtime, the current indices in question are passed as indices, along
		with the range specifications and current parameter context.
	'''

	def __init__(self, parameters, ranges, params={}, masks=None, function=None, function_args=(), function_kwargs={}, nprocs=None, distributed=False, ranges_eval=None, progress=True):
		self.p = parameters
		self.ranges = ranges
		self.function = function
		self.function_args = function_args
		self.function_kwargs = function_kwargs
		self.params = params
		self.masks = masks
		self.nprocs = nprocs
		self.distributed = distributed
		self.ranges_eval = ranges_eval
		self.progress = progress

		if current_process().name != "MainProcess" or threading.current_thread().name != "MainThread":
			self.nprocs = 1
			self.distributed = False

	@property
	def p(self):
		'''
		A reference to a Parameters instance.

		You can update this reference using:

		>>> iterator.p = <Parameters Instance>
		'''
		return self.__p
	@p.setter
	def p(self, parameters):
		self.__p = parameters

	@property
	def ranges(self):
		'''
		A reference to the list of ranges stored by the iterator.

		You can change the ranges used by the iterator using:

		>>> iterator.ranges = <Ranges specification>

		Note that this will reset :func:`ranges_eval`.
		'''
		return self.__ranges
	@ranges.setter
	def ranges(self, ranges):
		if isinstance(ranges, dict):
			ranges = [ranges]
		self.__ranges = ranges
		self.__ranges_eval = None

	@property
	def function(self):
		'''
		A reference to the callable to be called at each iteration, which is most likely a function or method (or None).

		You can change the callable using:

		>>> iterator.function = <callable>
		'''
		return self.__function
	@function.setter
	def function(self, function):
		if not isinstance(function, (type(None), types.FunctionType, types.MethodType)):
			raise ValueError("`function` must be a function or a method.")
		self.__function = function

	@property
	def function_kwargs(self):
		'''
		A reference to the dictionary of kwargs to passed to the callable at each iteration.

		You can change the kwargs using:

		>>> iterator.function_kwargs = <kwargs dict>
		'''
		return self.__function_kwargs
	@function_kwargs.setter
	def function_kwargs(self, function_kwargs):
		if not isinstance(function_kwargs, dict):
			raise ValueError("`function_kwargs` must be a dictionary of keyword arguments.")
		self.__function_kwargs = function_kwargs

	@property
	def params(self):
		'''
		A reference to the parameter context used by the iterator.

		You can change the parameter context using:

		>>> iterator.params = <parameters dictionary>

		Note that this will reset :func:`ranges_eval`.
		'''
		return self.__params
	@params.setter
	def params(self, params):
		if not isinstance(params, dict):
			raise ValueError("`params` must be a dictionary of parameter values (with parameters as keys).")
		self.__params = params
		self.__ranges_eval = None

	@property
	def masks(self):
		'''
		The list of mask callables used to filter which indices in the cartesian
		product of ranges are to be considered.

		You can change the masks using:

		>>> iterator.masks = <list of masks>
		'''
		return self.__masks
	@masks.setter
	def masks(self, masks):
		self.__masks = masks

	@property
	def nprocs(self):
		'''
		The number of processes to use (if positive), the number of CPUs to leave free
		(if negative), or None to default to using all CPUs.

		You can change nprocs using:

		>>> iterator.nprocs = <integer or None>
		'''
		return self.__nprocs
	@nprocs.setter
	def nprocs(self, nprocs):
		self.__nprocs = nprocs

	@property
	def ranges_eval(self):
		'''
		A previously evaluated ranges_eval from ranges_expand which can used to
		shortcut the range evaluation phase, and to ensure consistency when the
		range sampler is stochastic. If not specified when constructing the iterator,
		it will be generated when access it via this property, and then cached for later
		use.

		You can override ranges_eval using:

		>>> iterator.ranges_eval = <Previously generated ranges_eval>
		'''
		if self.__ranges_eval is None:
			self.__ranges_eval = self.ranges_expand()[0]
		return self.__ranges_eval
	@ranges_eval.setter
	def ranges_eval(self, ranges_eval):
		self.__ranges_eval = ranges_eval

	def ranges_expand(self):
		'''
		ranges_expand()

		:returns: A two-tuple of a structured numpy.ndarray with keys that are the parameters being iterated over and values being their current non-dimensional value, and the list of indices to consider as filtered by masks.

		For example:

		>>> iterator = RangesIterator(parameters=p, ranges=[{'x':(0,1,2)},{'y':(3,4,2)}])
		>>> iterator.ranges_expand()
		(array([[(0.0, 3.0), (0.0, 4.0)],
		        [(1.0, 3.0), (1.0, 4.0)]],
		       dtype=[('x', '<f8'), ('y', '<f8')]), [(0, 0), (0, 1), (1, 0), (1, 1)])
		'''
		return self.__ranges_expand(masks=self.masks, params=self.params.copy(), ranges_eval=self.__ranges_eval)

	@property
	def progress(self):
		'''
		A boolean indicating whether progress should be shown, or a callable object
		which takes arguments:
			- `total`: The total number of computations to be performed.
			- `completed`: The number of computations completed.
			- `start_time`: When the computation started (as a `datetime.datetime` object).

		You can change progress using:

		>>> iterator.progress = <bool or callable>
		'''
		return self.__progress
	@progress.setter
	def progress(self, progress):
		self.__progress = progress

	def __ranges_expand(self, level=0, iteration=tuple(), masks=None, indices=None, params=None, ranges_eval=None):
		'''
		This method generates a list of different parameter configurations
		'''
		if indices is None:
			indices = []
		if params is None:
			params = {}

		pam_ranges = self.ranges[level]

		# # Interpret ranges
		pam_values = {}
		count = None

		for param, pam_range in pam_ranges.items():
			if ranges_eval is not None and ranges_eval.ndim == len(self.ranges) and param in ranges_eval.dtype.fields.keys() and not np.any(np.isnan(ranges_eval[param])):  # If values already exist in ranges_eval, reuse them
				pam_values[param] = ranges_eval[param][iteration + (slice(None),) + tuple([0] * (ranges_eval.ndim - len(iteration) - 1))]

		tparams = params.copy()
		tparams.update(pam_ranges)
		tparams.update(pam_values)

		pam_values = self.p.range(list(pam_ranges.keys()), **tparams)

		c = len(pam_values[param])
		count = c if count is None else count
		if c != count:
			raise ValueError("Parameter ranges for %s are not consistent in count: %s" % (param, pam_ranges))

		if ranges_eval is None or ranges_eval.ndim < level + 1:
			ranges_eval = self.__extend_ranges(ranges_eval, list(pam_ranges.keys()), count)

		for i in range(count):
			current_iteration = iteration + (i,)

			# Generate slice corresponding all the components of range_eval this iteration affects
			s = current_iteration + tuple([slice(None)] * (ranges_eval.ndim - len(current_iteration)))

			# Update parameters
			for param, pam_value in pam_values.items():
				ranges_eval[param][s] = pam_value[i]
				if np.isnan(pam_value[i]):
					raise ValueError("Bad number for parameter %s @ indices %s" % (param, str(current_iteration)))

				params[param] = pam_value[i]

			if level < len(self.ranges) - 1:
				# Recurse problem
				ranges_eval, _ = self.__ranges_expand(level=level + 1, iteration=current_iteration, indices=indices, params=params, masks=masks, ranges_eval=ranges_eval)
			else:
				if masks is not None and isinstance(masks, list):
					if not any([mask(indices=current_iteration, ranges=self.ranges, params=params) for mask in masks]):
						continue

				indices.append(current_iteration)

		return ranges_eval, indices

	def __extend_ranges(self, ranges_eval, labels, size):
		dtype_delta = [(label, float) for label in labels]
		if ranges_eval is None:
			ranges_eval = np.zeros(size, dtype=dtype_delta)
			ranges_eval.fill(np.nan)
		else:
			final_shape = ranges_eval.shape + (size,)
			ranges_eval = np.array(np.repeat(ranges_eval, size).reshape(final_shape), dtype=ranges_eval.dtype.descr + dtype_delta)
		for label in labels:
			ranges_eval[label].fill(np.nan)
		return ranges_eval

	def __index_to_dict(self, index, ranges_eval):
		params = {}
		vs = ranges_eval[index]
		names = ranges_eval.dtype.names
		for i, param in enumerate(names):
			params[param] = vs[i]
		return params

	def __get_params_for_index(self, index, ranges_eval):
		params = self.params.copy()
		params.update(self.__index_to_dict(index, ranges_eval))
		return params

	def __iter__(self):
		ranges_eval, indices = self.ranges_expand()

		start_time = datetime.datetime.now()
		if self.distributed not in (None, False) and  self.function is not None:
			try:
				from .utility.symmetric import DistributedParallelMap
			except:
				raise RuntimeError("The `dispy` module is required for distributed iteration.")

			cluster_kwargs = {} if self.distributed is True else self.distributed
			dpm = DistributedParallelMap(self.function, progress=self.progress, **cluster_kwargs)

			for res in dpm.iterate([(i, self.function_args, {'params':self.__get_params_for_index(i, ranges_eval)}) for i in indices], count_offset=0, count_total=len(indices), start_time=start_time, base_kwargs=self.function_kwargs):
				yield res

		elif self.nprocs not in [0, 1] and self.function is not None:
			from .utility.symmetric import AsyncParallelMap
			apm = AsyncParallelMap(self.function, progress=self.progress, nprocs=self.nprocs, spawnonce=True)

			for res in apm.iterate([(i, self.function_args, {'params':self.__get_params_for_index(i, ranges_eval)}) for i in indices], count_offset=0, count_total=len(indices), start_time=start_time, base_kwargs=self.function_kwargs):
				yield res
		else:
			for i, index in enumerate(indices):
				if self.function is None:
					yield (index, self.__index_to_dict(index, ranges_eval))
				else:
					yield (index, self.function(*self.function_args, params=self.__index_to_dict(index, ranges_eval), **self.function_kwargs))
				if self.progress is not False:
					if self.progress is True:
						self.__print_progress_fallback(len(indices), i + 1, start_time)
					else:
						self.progress(len(indices), i + 1, start_time)

	def __print_progress_fallback(self, total, completed, start_time):
		progress = float(completed) / total

		sys.stderr.write("\r %3d%% | %d of %d | Memory usage: %.2f MB" % (
								progress * 100,
								completed,
								total,
								resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024.)
						)

		if progress > 0:
			delta = datetime.datetime.now() - start_time
			delta = datetime.timedelta(delta.total_seconds() / 24 / 3600 * (1 - progress) / progress)
			sys.stderr.write(" | Remaining: %02dd:%02dh:%02dm:%02ds" % (
					delta.days,
					delta.seconds / 3600,
					delta.seconds / 60 % 60,
					delta.seconds % 60
				)
			)

		if total == completed:
			sys.stderr.write('\n')

		sys.stderr.flush()
