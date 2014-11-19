import numpy as np
import copy
import datetime

# from abc import ABCMeta, abstractmethod, abstractproperty
#
# class Iterated(object):
#	 __metaclass__ = ABCMeta
#
#	 @abstractmethod
#	 def result_type(self,*args,**kwargs):
#	 pass
#
#	 @abstractmethod
#	 def result_shape(self,*args,**kwargs):
#	 pass
#
#	 @abstractmethod
#	 def init_results(self,*args,**kwargs):
#	 pass
#
# class MeasurementResults(object):
#
# 	def __init__(self,ranges,ranges_eval,data,runtime=None,path=None,samplers={}):
# 		self.ranges = ranges
# 		self.ranges_eval = ranges_eval
# 		self.data = data
# 		self.runtime = 0 if runtime is None else runtime
# 		self.path = path
# 		self.samplers = samplers
#
# 	def update(self,**kwargs):
# 		for key,value in kwargs.items():
# 			if key not in ['ranges','ranges_eval','data','runtime','path','samplers']:
# 				raise ValueError("Invalid update key: %s" % key)
# 			if key is "runtime":
# 				self.runtime += value
# 			else:
# 				setattr(self,key,value)
# 		return self
#
# 	@property
# 	def is_complete(self):
# 		return len(np.where(np.isnan(self.data.view('float')))[0]) == 0
#
# 	@property
# 	def continue_mask(self):
# 		def continue_mask(indicies, ranges=None, params={}): # Todo: explore other mask options
# 				return np.any(np.isnan(self.data[indicies].view('float')))
# 		return continue_mask
#
# 	@staticmethod
# 	def _process_ranges(ranges,defunc=False,samplers={}):
# 		if ranges is None:
# 			return ranges
# 		ranges = copy.deepcopy(ranges)
# 		for range in ranges:
# 			for param,spec in range.items():
# 				if defunc and type(spec[-1]) == types.FunctionType:
# 					spec = list(spec)
# 					spec[-1] = spec[-1].__name__
# 					spec = tuple(spec)
# 					range[param] = spec
# 				if not defunc and len(spec) > 3 and type(spec[-1]) == str and spec[-1] in samplers:
# 					spec = list(spec)
# 					spec[-1] = samplers[spec[-1]]
# 					spec = tuple(spec)
# 					range[param] = spec
# 		return ranges
#
# 	def save(self,path=None,samplers=None):
# 		if path is None:
# 			path = self.path
# 		if samplers is None:
# 			samplers = self.samplers
# 		else:
# 			self.samplers = samplers
# 		if path is None:
# 			raise ValueError("Output file was not specified.")
#
# 		s = shelve.open(path)
# 		s['ranges'] = MeasurementResults._process_ranges(self.ranges,defunc=True,samplers=samplers)
# 		s['ranges_eval'] = self.ranges_eval
# 		s['results'] = self.data
# 		s['runtime'] = self.runtime
# 		s.close()
#
# 	@classmethod
# 	def load(cls,path,samplers={}):
# 		s = shelve.open(path)
# 		ranges = MeasurementResults._process_ranges(s.get('ranges'),defunc=False,samplers=samplers)
# 		ranges_eval = s.get('ranges_eval')
# 		data = s.get('results')
# 		runtime = s.get('runtime')
# 		s.close()
# 		return cls(ranges=ranges,ranges_eval=ranges_eval,data=data,runtime=runtime,path=path,samplers=samplers)

#### Actual iteration code

def iterate(*args,**kwargs):
	'''
	A wrapper around the `Measurement.iterate_yielder` method in the event that
	one does not want to deal with a generator object. This simply returns
	the final result.
	'''
	from collections import deque
	return deque(iterate_yielder(*args, yield_every=None, **kwargs),maxlen=1).pop()

class RangesIterator(object):

	def __init__(self,ranges,parameters=None):
		# Check if ranges is just a single range, and if so make it a list
		if isinstance(ranges,dict):
			ranges = [ranges]
		self.ranges = ranges
		self.p = parameters

	def ranges_expand(self,level=0,iteration=tuple(),masks=None,indicies=[],params={},ranges_eval=None):
		'''
		This method generates a list of different parameter configurations
		'''

		pam_ranges = self.ranges[level]

		## Interpret ranges
		pam_values = {}
		count = None
		for param, pam_range in pam_ranges.items():

			if ranges_eval is not None and ranges_eval.ndim == len(self.ranges) and param in ranges_eval.dtype.fields.keys() and not np.any(np.isnan(ranges_eval[param])): # If values already exist in ranges_eval, reuse them
				pam_values[param] = ranges_eval[param][iteration + (slice(None),) + tuple([0]*(results.ranges_eval.ndim-len(iteration)-1))]
			else:
				tparams = params.copy()
				tparams[param] = pam_range
				pam_values[param] = self.p.range(param,**tparams)

		c = len(pam_values[param])
		count = c if count is None else count
		if c != count:
			raise ValueError, "Parameter ranges for %s are not consistent in count: %s" % (param, pam_ranges)

		if ranges_eval is None or ranges_eval.ndim < level + 1:
			ranges_eval = self.__extend_ranges(ranges_eval, pam_ranges.keys(), count)

		for i in xrange(count):
			current_iteration = iteration + (i,)

			# Generate slice corresponding all the components of range_eval this iteration affects
			s = current_iteration + tuple([slice(None)]*(ranges_eval.ndim-len(current_iteration)))

			# Update parameters
			for param, pam_value in pam_values.items():
				ranges_eval[param][s] = pam_value[i]
				if np.isnan(pam_value[i]):
					raise ValueError ("Bad number for parameter %s @ indicies %s"% (param,str(current_iteration)))

			if level < len(self.ranges) - 1:
				# Recurse problem
				ranges_eval,_ = self.ranges_expand(level=level+1,iteration=current_iteration,indicies=indicies,params=params,ranges_eval=ranges_eval)
			else:
				if masks is not None and isinstance(masks,list):
					skip = False
					for mask in masks:
						if not mask(current_iteration,ranges=ranges,params=params):
							skip = True
						break
					if skip:
						continue

				indicies.append( current_iteration )

		return ranges_eval, indicies

	def __extend_ranges(self,ranges_eval,labels,size):
		dtype_delta = [(label,float) for label in labels]
		if ranges_eval is None:
			ranges_eval = np.zeros(size,dtype=dtype_delta)
			ranges_eval.fill(np.nan)
		else:
			final_shape = ranges_eval.shape + (size,)
			ranges_eval = np.array(np.repeat(ranges_eval,size).reshape(final_shape),dtype=ranges_eval.dtype.descr + dtype_delta)
		for label in labels:
			ranges_eval[label].fill(np.nan)
		return ranges_eval

	def __index_to_dict(self,index,ranges_eval):
		params = {}
		vs = ranges_eval[index]
		names = ranges_eval.dtype.names
		for i,param in enumerate(names):
			params[param] = vs[i]
		return params

	def iterate(self,function,function_kwargs={},params={},masks=None,nprocs=None,ranges_eval=None):

		ranges_eval,indicies = self.ranges_expand(masks=masks, ranges_eval=ranges_eval, params=params)

		start_time = datetime.datetime.now()
		if nprocs not in [0,1]:
			from .utility.symmetric import AsyncParallelMap
			apm = AsyncParallelMap(function,progress=True,nprocs=nprocs,spawnonce=False)
			callback = None

			for res in apm.iterate([(i,tuple(),{'params':self.__index_to_dict(i,ranges_eval)}) for i in indicies],count_offset=0,count_total=len(indicies),start_time=start_time, base_kwargs=function_kwargs ):
				yield res
		else:
			apm = None
			#levels_info = [{'name':','.join(ranges[i].keys()),'count':ranges_eval.shape[i]} for i in xrange(ranges_eval.ndim)]
			#callback = IteratorCallback(levels_info,ranges_eval.shape)

			for i in indicies:
				yield (i, function(params=self.__index_to_dict(i,ranges_eval),**function_kwargs))
