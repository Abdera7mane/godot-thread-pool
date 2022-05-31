tool

# warning-ignore-all:return_value_discarded
# warning-ignore-all:unused_signal
# warning-ignore-all:shadowed_variable

class_name ThreadPool

const DEFAULT_MIN: int = 1
const DEFAULT_MAX: int = 20

var executor: ThreadedExecutor

func _init(min_threads: int = DEFAULT_MIN, max_threads: int = DEFAULT_MAX) -> void:
	executor = ThreadedExecutor.new(min_threads, max_threads)

func submit_task(function: FuncRef, arguments: Array = []):
	var task: Task = Task.new()
	task.function = function
	task.arguments = arguments
	
	executor.push(task)
	
	reference()
	
	var result = yield(task, "completed")
	task.done()
	
	unreference()
	
	return result

func get_class() -> String:
	return "ThreadPool"

func _to_string() -> String:
	return "[%s:%d]" % [get_class(), get_instance_id()]

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PREDELETE:
			executor.destroy()

class ThreadedExecutor extends Object:
	var threads: Array
	var mutex: Mutex
	var semaphore: Semaphore
	var max_threads: int
	var min_threads: int
	var active: bool
	var task_queue: Array
	var active_tasks: int

	func _init(min_threads: int, max_threads: int) -> void:
		mutex = Mutex.new()
		semaphore = Semaphore.new()
		
		active = true
		self.max_threads = max_threads
		self.min_threads = int(max(min_threads, max_threads))
		for i in self.min_threads:
			append_thread()
	
	func append_thread() -> void:
		var thread: Thread = Thread.new()
		thread.start(self, "_run", thread)
		threads.append(thread)
	
	func push(task: Task) -> void:
		lock()
		if active_tasks == threads.size() and active_tasks < max_threads:
			append_thread()
		task_queue.append(task)
		active_tasks += 1
		unlock()
		
		notify()
	
	func notify() -> void:
		semaphore.post()
	
	func destroy() -> void:
		lock()
		active = false
		unlock()
		
		if threads.size() == 0:
			call_deferred("free")
			return
		
		for thread in threads:
			notify()
	
	func lock() -> void:
		mutex.lock()
	
	func unlock() -> void:
		mutex.unlock()
	
	func _join(thread: Thread) -> void:
		thread.wait_to_finish()
		threads.erase(thread)
		if threads.size() == 0:
			call_deferred("free")
	
	func _run(thread: Thread) -> void:
		while true:
			lock()
			var exit: bool = not active
			unlock()
			
			if exit:
				break
			
			var task: Task
			lock()
			if task_queue.empty():
				unlock()
				semaphore.wait()
				continue
			else:
				task = task_queue.pop_front()
			unlock()
			
			if task:
				task.execute()
				lock()
				active_tasks -= 1
				unlock()
		
		call_deferred("_join", thread)

class Task extends Object:
	signal completed(result)
	
	var function: FuncRef
	var arguments: Array
	
	func execute():
		var result = function.call_funcv(arguments)
		call_deferred("emit_signal", "completed", result)
	
	func done():
		call_deferred("free")
