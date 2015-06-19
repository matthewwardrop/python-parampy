
# Multiprocessing code for qubricks
# Inspired by: http://stackoverflow.com/questions/3288595/multiprocessing-using-pool-map-on-a-function-defined-in-a-class

#WARNING: This module is currently under development.

import Queue
import multiprocessing, traceback, logging, resource
import sys, gc
import warnings
import datetime

heap = None
def set_heap(hp):
	global heap
	heap = hp

def get_heap(hp):
	global heap
	return heap

def error(msg, *args):
	return multiprocessing.get_logger().error(msg, *args)

def warn(msg, *args):
	return multiprocessing.get_logger().warn(msg, *args)

def spawn(f):
	def fun(q_in, q_out):
		warnings.simplefilter("ignore")
		initial_memory_usage = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
		while True:
			i, args, kwargs = q_in.get()
			if i is None:
				break

			try:
				r = f(*args, **kwargs)
			except Exception as e:
				error(traceback.format_exc())
				raise e

			q_out.put((i, r))

			gc.collect()

			if resource.getrusage(resource.RUSAGE_SELF).ru_maxrss > 2*initial_memory_usage:
				warn('Memory usage: %s (kb)' % resource.getrusage(resource.RUSAGE_SELF).ru_maxrss)

	return fun

def spawnonce(f):
	def fun(q_in, q_out):
		warnings.simplefilter("ignore")

		i, args, kwargs = q_in.get()
		if i is None:
			return

		r = None
		try:
			r = f(*args, **kwargs)
		except Exception as e:
			error(traceback.format_exc())
			raise e

		q_out.put((i, r))

	return fun

class ParallelMap(object):

	def __init__(self, f, progress=False, **kwargs):
		self.f = f
		self.progress = progress
		self.init(**kwargs)

	def init(self):
		pass

	def reset(self, f=None, count_offset=None, count_total=1, **kwargs):
		if f is not None:
			self.f = f

		self.count = 0
		self.count_offset = count_offset
		self.count_total = count_total

		self.start_time = None

		self._reset(**kwargs)

	def _reset(self):
		pass

	def _print_progress(self):
		progress = self.progress
		if self.progress is True:
			progress = self.__print_progress_fallback
		else:
			return

		progress(
			total = self.count_total,
			completed = self.count + ( self.count_offset if self.count_offset is not None else 0 ),
			start_time = self.start_time
		)

	def __print_progress_fallback(self, total, completed, start_time):
		progress = float(completed) / total

		sys.stderr.write("\r %3d%% | %d of %d | Memory usage: %.2f MB" % (
								progress * 100,
								completed,
								total,
								resource.getrusage(resource.RUSAGE_SELF).ru_maxrss/1024.)
						)

		if progress > 0:
			delta = datetime.datetime.now() - start_time
			delta = datetime.timedelta( delta.total_seconds()/24/3600 * (1-progress)/progress )
			sys.stderr.write(" | Remaining: %02dd:%02dh:%02dm:%02ds" % (
					delta.days,
					delta.seconds/3600,
					delta.seconds/60 % 60,
					delta.seconds % 60
				)
			)

		if completed == total:
			sys.stderr.write('\n')

		sys.stderr.flush()

	def map(self, X, count_offset=None, count_total=None, start_time=None):
		return list(self.iterate(X,count_offset=count_offset,count_total=count_total,start_time=start_time))

	def iterate(self, X, count_offset=None,count_total=None,start_time=None, base_kwargs=None):
		pass

class AsyncParallelMap(ParallelMap):

	def init(self, nprocs=None, spawnonce=True):
		multiprocessing.log_to_stderr(logging.WARN)
		if nprocs is None:
			self.nprocs = multiprocessing.cpu_count()
		else:
			self.nprocs = multiprocessing.cpu_count() + nprocs if nprocs < 0 else nprocs
		self.proc = []
		self.spawnonce = spawnonce

	def _reset(self):
		self.q_in = multiprocessing.Queue(1 if not spawnonce else self.nprocs)
		self.q_out = multiprocessing.Queue()

		while len(self.proc) > 0:
			self.proc.pop().terminate()
		if not self.spawnonce:
			self.proc = [multiprocessing.Process(target=spawn(self.f), args=(self.q_in, self.q_out)) for _ in range(self.nprocs)]
			for p in self.proc:
				p.daemon = True
				p.start()

	def __sweep_results(self,timeout=0):
		while True:
			try:
				yield self.q_out.get(timeout=timeout)
				self.count += 1
			except Queue.Empty:
				break
			except:
				break

	def iterate(self, X, count_offset=None,count_total=None,start_time=None, base_kwargs=None):
		self.reset(self.f,count_offset=count_offset,count_total=count_total)

		self.start_time = start_time if start_time is not None else datetime.datetime.now()
		self.count_total = count_total if count_total is not None else len(X)

		if not self.spawnonce:
			X = X + [(None, None, None)] * self.nprocs  # add sentinels

		for i, (x_indices, x_args, x_kwargs) in enumerate(X):

			if self.spawnonce and self.count + self.nprocs <= i:  # Wait for processes to finish before starting new ones
				yield self.q_out.get()
				self.count += 1

			if base_kwargs is not None:
				kwargs = base_kwargs.copy()
				kwargs.update(x_kwargs)
			else:
				kwargs = x_kwargs
			self.q_in.put( (x_indices, x_args, kwargs) )
			if self.spawnonce:
				self.proc.append(multiprocessing.Process(target=spawnonce(self.f), name="ParamPy-%d"%i, args=(self.q_in, self.q_out)))
				self.proc[-1].daemon = False
				self.proc[-1].start()
				while len(self.proc) > 2*self.nprocs:
					p = self.proc.pop(0)
					if not p.is_alive():
						p.terminate()
						del p

			for result in self.__sweep_results():
				yield result

			if self.progress is not False:
				self._print_progress()

		self.q_in.close()

		while self.count < len(X) - (self.nprocs if not self.spawnonce else 0):
			yield self.q_out.get()
			self.count += 1
			if self.progress is not False:
				self._print_progress()

		if not self.spawnonce:
			[p.terminate() if p.is_alive() else False for p in self.proc]

try:
	import dispy
	assert(float(dispy.__version__) >= 4.1)
	import dispy.httpd
	import threading

	class DistributedParallelMap(ParallelMap):

		def init(self, **cluster_opts):
			self.cluster_opts = cluster_opts
			self.lock = threading.Condition()

		def _reset(self, cluster_opts=None):
			self.cluster_opts = cluster_opts if cluster_opts is not None else self.cluster_opts
			self.jobs = []
			self.done = []
			http_server = self.cluster_opts.pop('http_server',False)
			self.cluster = dispy.JobCluster(self.f, callback=self.__receive_callback, **self.cluster_opts)
			if http_server:
				self.http_server = dispy.httpd.DispyHTTPServer(self.cluster)
			else:
				self.http_server = None

		def __receive_callback(self, job):
			if job.result is None:
				print
				print "--------"
				print "Job failed to successfully complete on %s with result:" % job.ip_addr
				print job.result
				print job.exception
				print job.stdout
				print job.stderr
				print "-------"
				print
			self.done.append(job)

			self.lock.acquire()
			self.lock.notifyAll()
			self.lock.release()

		def iterate(self, X, count_offset=None,count_total=None,start_time=None, base_kwargs=None):
			self.reset(count_offset=count_offset,count_total=count_total)

			self.start_time = start_time if start_time is not None else datetime.datetime.now()
			self.count_total = count_total if count_total is not None else len(X)

			for (x_indices, x_args, x_kwargs) in X:
				if base_kwargs is not None:
					kwargs = base_kwargs.copy()
					kwargs.update(x_kwargs)
				else:
					kwargs = x_kwargs

				job = self.cluster.submit(*x_args, **kwargs)
				job.id = x_indices
				self.jobs.append(job)

			self._print_progress()

			while self.count < len(X):
				while len(self.done) > 0:
					job = self.done.pop()
					yield (job.id, job.result)
					self.count += 1
					self._print_progress()
				if self.count < len(X):
					self.lock.acquire()
					self.lock.wait(1.) # Just in case a result slipped through while incorporated below, we wait a max of 1 second before polling again.
					self.lock.release()

			self._finalise()

		def _finalise(self):
			self.cluster.wait()
			self.cluster.stats()

			if self.http_server is not None:
				self.http_server.shutdown()

			self.cluster.close()

except:
	pass
