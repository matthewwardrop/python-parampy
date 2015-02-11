import numpy as np
import datetime

class RangesIterator(object):

	def __init__(self,ranges,parameters=None):
		# Check if ranges is just a single range, and if so make it a list
		if isinstance(ranges,dict):
			ranges = [ranges]
		self.ranges = ranges
		self.p = parameters

	def ranges_expand(self,level=0,iteration=tuple(),masks=None,indicies=None,params=None,ranges_eval=None):
		'''
		This method generates a list of different parameter configurations
		'''
		if indicies is None:
			indicies = []
		if params is None:
			params = {}

		pam_ranges = self.ranges[level]

		## Interpret ranges
		pam_values = {}
		count = None
		for param, pam_range in pam_ranges.items():

			if ranges_eval is not None and ranges_eval.ndim == len(self.ranges) and param in ranges_eval.dtype.fields.keys() and not np.any(np.isnan(ranges_eval[param])): # If values already exist in ranges_eval, reuse them
				pam_values[param] = ranges_eval[param][iteration + (slice(None),) + tuple([0]*(ranges_eval.ndim-len(iteration)-1))]
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

				params[param] = pam_value[i]

			if level < len(self.ranges) - 1:
				# Recurse problem
				ranges_eval,_ = self.ranges_expand(level=level+1,iteration=current_iteration,indicies=indicies,params=params,masks=masks,ranges_eval=ranges_eval)
			else:
				if masks is not None and isinstance(masks,list):
					if not any( [mask(current_iteration,ranges=self.ranges,params=params) for mask in masks] ):
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
			apm = AsyncParallelMap(function,progress=True,nprocs=nprocs,spawnonce=True)
			callback = None

			for res in apm.iterate([(i,tuple(),{'params':self.__index_to_dict(i,ranges_eval)}) for i in indicies],count_offset=0,count_total=len(indicies),start_time=start_time, base_kwargs=function_kwargs ):
				yield res
		else:
			apm = None
			#levels_info = [{'name':','.join(ranges[i].keys()),'count':ranges_eval.shape[i]} for i in xrange(ranges_eval.ndim)]
			#callback = IteratorCallback(levels_info,ranges_eval.shape)

			for i in indicies:
				yield (i, function(params=self.__index_to_dict(i,ranges_eval),**function_kwargs))
