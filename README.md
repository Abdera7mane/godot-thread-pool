# Godot Thread Pool

Thread pool implementation in GDScript for running multiple tasks in parallel. Unlike other implementations I have encountered this doesn't leak memory when the pool is unused and threads are joined eventually after the `ThreadPool` instance is freed from memory.

## Usage

Constructing a `ThreadPool` instance takes two optional arguments:
*  `min_threads` for the minimum number of threads to start with. [*optional*]
* `max_threads` for a maximum of threads to allocate when needed. [*optional*]

Sending a task to the thread pool is fairly easy via the `submit_task` method, which takes 2 arguments:
* `function` a [FuncRef](https://docs.godotengine.org/en/3.5/classes/class_funcref.html).
* `arguments` an array of arguments to pass to `function`. [*optional*]

The task will then be pushed into a queue until a thread claim it and execute it.

`sumbit_task` is a [coroutine](https://docs.godotengine.org/en/3.5/tutorials/scripting/gdscript/gdscript_basics.html#coroutines-with-yield), you can use `yield()` to wait for task completion or retrieving the return value.

### Code example:
```gdscript
# Instantiate a thread pool
# with a minimum of 5 threads and maximum of 10
var thread_pool: = ThreadPool.new(5, 10)

func example() -> void:
	# queue a task to run inside a thread
	thread_pool.submit_task(funcref(self, "some_task1"))

	# wait for the task to finish
	var state = thread_pool.submit_task(funcref(self, "some_task2", [2, 5])
	var result: int = yield(state, "completed")

	assert(result == 7)

func some_task1() -> void:
	# some processing ...
	pass

func some_task2(a: int, b: int) -> int:
	return a + b

```