#set document(author: "Adrien Vannson", title: "Internship report")

#set page(numbering: "1", number-align: center)
#set text(font: "New Computer Modern", lang: "en")
#set par(leading: 0.55em, first-line-indent: 1.8em, justify: true)
#set heading(numbering: "I 1.1.a")
#show heading: set block(above: 1.4em, below: 1em)

#[
  #set align(center)
  #set page(numbering: none)

  #v(8em)
  #text(1.8em, weight: 700, [Python Data Processing on Supercomputers for Large Parallel Numerical Simulations])
  #v(1.2em)

  *Adrien #smallcaps[Vannson]* \
  #smallcaps[EPFL, ENS de Lyon]

  #v(1.2em)

  Internship supervised by: \
  *Bruno #smallcaps[Raffin]* \
  #smallcaps[DataMove team]

  #v(2.4fr)

  #text(1.1em, "10 February 2025 -- 8 August 2025")
]

// Table of contents.
#show outline.entry.where(
  level: 1
): it => {
  v(12pt, weak: true)
  strong(it)
}

#outline(depth: 3)
#pagebreak()


#set page(columns: 2)

= Introduction

Physical simulations such as Gysela @gysela or Parflow (TODO ref?).

This Master thesis introduces #smallcaps[Doreisa] -- Dask-on-Ray Enabled In Situ Analytics --, a new way to process data coming from HPC simulations, easily and in a distributed and efficient manner. This system is able to scale on supercomputers such as the Adastra and Jean Zay, 

== Performance requirements

The proposed solution needs to scale well to some of the biggest supercomputers such as the french Adastra and Jean Zay.

Adastra is hosted by the _Centre Informatique National de l’Enseignement Supérieur (CINES)_ in Montpellier. In November 2024, it was ranked \#30 in Top500, with an Rmax value of 46.10 PFlop/s. In addition to login and pre/post processing nodes, Adastra is equiped with 544 scalar nodes, and . The detailed specification is available on Adasta's website @adastra.

Jean Zay is . In November 2024, it was ranked \#27 in Top500, with an Rmax value of 52.18 PFlop/s.

Given the architecture of these supercomputers, Doreisa should be able to scale to systems having thousands of nodes, producing tens of thousands to potentially hundreds of thousands of chunks of data per iteration.

== Structure of this report

@state-of-the-art goes through the main research projects related to the subject, as well as the some tools used by these projects that will be useful for Doreisa. The first section of @doreisa-design introduces a proof of concept of Doreisa, working correctly with limited performance. The following subsections details improvements made to this solution, until the most advanced version. @performance-evaluation evaluates the performance of the application in various scenarios, and compare them to existing solutions. @challenges mentions some challenges that were encountered during the creation of Doreisa.

The Doreisa implementation is available on Github @doreisa-github. The experiments run on the various supercomputers are available on Github as well @doreisa-internship-github.

= State of the art <state-of-the-art>

== Tools

The following tools are used in the . Some of the research projects related to the this Master project also rely on them.

=== Dask

Dask @dask is a Python framework aiming at making distributed computing easy. The basic workflow to run computations with Dask is composed of two steps:

 - *Building a task graph.* The distributed computation is represented as a task graph, as the one in @dask-graph-mean. The task graph is a directed acyclic graph where each node represents a computation. There is an edge from a node $T_1$ to a node $T_2$ if $T_1$ needs the result of $T_2$ to be executed. Internally, a task graph can be represented as a simple Python dictionnary.
 - *Running the computation.* The graph is then shipped to a scheduler, which is in charge of executing all the tasks and returning the final result of the computation. Dask provides several schedulers, suited to different use case: a threaded scheduler, a multiprocessing scheduler as well as a distributed scheduler.

#figure(
    image("resources/dask-graph-mean.png", width: 80%),
    caption: [Example of a Dask task graph],
) <dask-graph-mean>

Dask also provides APIs similar to pandas and numpy: the user can call functions similar to the ones defined in these libraries. They .

In particular, a Dask array is a distributed implementation of numpy arrays. It is composed of several chunks, each chunk being represented as a numpy array. Performing computations on such a graph produces a task graph that can be executed in a distributed manner, hiding all the complexity from the final user.

Unfortunately, Dask suffer from several limitations that have an impact on performance:
  - Data can't be shared between workers without a copy, even when the workers are running on the same node.
  - Dask's scheduler is centralized, and can become a bottleneck in very large-scale computations. According to Dask's documentation @dask-actors-motivation, it can handle at most around 4000 tasks per second.

=== Ray

Ray is a Python framework. One of its building blocks, Ray Core, offers a low level API for distributed computing. Ray also provides modules for AI training, model serving, reinforcement learning, etc. In the rest of this report, Ray will only stand for Ray Core.

As it is a simple and efficient system to define distributed computations, it was notably successfully used to create a state-of-the-art distributed shuffling system @exoshuffle.

The following sections will briefly introduce the main abstractions provided by Ray: object references, tasks and actors. Ray also provides advanced options to choose how tasks are scheduled, the lifetime of actors, support asynchronous code with `asyncio`, etc, but introducing them is out of the scope of this report. Ray doesn't include any API similar to Dask arrays.

==== Ray `ObjectRefs`

A Ray `ObjectRef` is a small Python object that points to some data. The data can be retrieved using the `ray.get` function.

An `ObjectRef` can be created by placing data directly in the Ray object store using the `ray.put` function. It can also point to the result of a call to a remote function or method, possibly before the function execution terminates.

`ObjectRefs` can be freely shared across the nodes of the Ray cluster: thanks to a distributed reference counting system, the memory is freed automatically when no `ObjectRef` pointing to it exists anymore.

#figure(
  [
    #set text(0.9em)

    ```python
    import ray

    object_ref = ray.put([1, 2, 3])
    assert isinstance(object_ref, ray.ObjectRef)
    assert ray.get(object_ref) == [1, 2, 3]
    ```
  ],
  caption: [Ray's `ObjectRefs`]
) <ray-refs>

==== Ray tasks

In Ray, a remote function is a function that can be executed remotely, on any available machine in the cluster. Calling a remote function will create a remote task whose result is represented by an `ObjectRef`. Calling `ray.get` on this reference will wait for the task to finish and return the result of the task.

Contrary to Dask, Ray is very flexible: a Ray task can create other tasks thanks to the distributed scheduler.

#figure(
  [
    #set text(0.9em)

    ```python
    import ray

    @ray.remote
    def f(n):
      # Some expensive computation
      return ...

    object_ref = f.remote(12)
    assert isinstance(object_ref, ray.ObjectRef)

    print(ray.get(object_ref))
    ```
  ],
  caption: [Execution of a Ray remote task]
) <ray-task>

==== Ray actors

Ray actors are instances of classes defined with the `ray.remote` decorator. They allow stateful computations.

#figure(
  [
    #set text(0.9em)

    ```python
    import ray

    @ray.remote
    class Actor:
      def __init__(self) -> None:
        self.n = 0

      def increase_counter(self) -> int:
        self.n += 1
        return self.n

    actor = Actor.remote()
    ray.get(actor.increase_counter.remote())  # 1
    ray.get(actor.increase_counter.remote())  # 2
    ray.get(actor.increase_counter.remote())  # 3
    ```
  ],
  caption: [Example of a Ray actor]
) <ray-actors>

=== Dask-on-Ray

Dask-on-Ray is a project aiming at bringing the best of Dask and Ray together. It allows executing a Dask task graph on a Ray cluster, allowing to use the simple Dask API while taking advantage of the good performance offered by Ray.

To use it, a Dask task graph should first be created, as with standard Dask. This task graph can be built using the high-level Dask abstractions such as Dask arrays. Then, Dask-on-Ray is called to execute the task graph. Dask-on-Ray is actually a Dask scheduler, that is a function taking two main parameters: a Dask task graph and a list of the keys to compute. The scheduler is in charge of computing the value of the requested keys and returning them. For each node of the task graph, the Dask-on-Ray scheduler performs a Ray `@remote` call to execute the computation on the Ray cluster.

As the arguments to the functions in the graph are passed directly to the Ray remote function, it is possible to put Ray's `ObjectRefs` as values in the task graph. The compute function will receive the underlying value, as expected.

=== PDI

PDI (the PDI Data Interface) is a project aiming at coupling C / C++ programs (typically MPI simulations) with plugins in charge of using the data for various tasks. Plugins make it possible to save the data to HDF5 files, export it to JSON, etc. The user needs to write a YAML file to choose how to use the data, without having to recompile the simulation code each time the usage changes.

In this project, we will use the Pycall plugin, which allows making the data available to a Python script as a Numpy array without copying it.

== Research projects

@dreher2014flexible explores a flexible solution to perfom _in situ_ and _in transit_ analytics by allowing the user to define a graph of tasks to be executed for the analytics. The model is simple (a task has some input, some output).

=== Deisa

Deisa

=== Reisa

Reisa @reisa is an attempt to solve the limitations of Deisa by relying on Ray instead of Dask. One of the main limitation of the approach is the lack of native array support. In Reisa, users no longer have a global view on the data as a Dask array: they have to manually define two callback functions:

== Supercomputers

=== Jean-Zay

The Jean-Zay supercomputer (see @jean-zay) is a powerful supercomputer located in Saclay, France. Following its extension in 2024, it has a peak computing power of 125.9 PFlop/s @jean-zay-presentation, which places it among the most powerful supercomputers on this planet.

#figure(
  image("resources/jean-zay.png", width: 100%),
  caption: [The Jean-Zay supercomputer],
) <jean-zay>

The experiments presented in this report were carried out using the CPU partition of Jean-Zay. This partition is composed of 720 nodes (at most 256 bookable at the same time), each having:
  - 2 Intel Cascade Lake 6248 processors (2 x 20 cores)
  - 192 Go of RAM

The tasks are submitted using SLURM.

= Doreisa: Dask-on-Ray Enabled In-Situ Analytics <doreisa-design>

== First proof of concept

This section describes the first proof of concept of Doreisa. This solution already made it possible to analyze data produced by HPC simulations easily. However, its design remains largely centralized, with one main actor quickly becoming the bottleneck of the analytics.

=== Design

The general design of the first version of Doreisa is shown in figure @doreisa-poc.

#place(
  auto,
  scope: "parent",
  float: true,
  [
    #figure(
      image("resources/doreisa-poc.png", width: 80%),
      caption: [Architecture of the first Doreisa proof of concept],
    ) <doreisa-poc>
  ],
)

Each iteration of the analysis pipeline consists of the following steps:

  1. The MPI processes terminate one iteration of the simulation. The data is ready for analytics. It is made available to Doreisa using PDI, which serves as an interface between Doreisa and the simulation code.
  2. The data produced by the simulation is placed in the Ray object store. An `ObjectRef` is produced: this reference to the data is sent to a main actor running on the head node.
  3. The head actor collects the references of all the processes. Once it has received all of them, it builds a Dask array from them.
  4. The user script receives the Dask array. It can be used as a standard Dask array, to perform any kind of analysis. Performing operations on the Dask array produces a task graph.
  5. The task graph is passed to the Dask-on-Ray scheduler that is in charge of executing it. Each Dask task is converted to a Ray task, and scheduled by Ray. Ray takes into account data locality when scheduling tasks, so unnecessary data movements should be avoided.

=== Performance evaluation

This first solution has the drawback of being really centralized: the head actor needs to collect an `ObjectRef` for each chunk produced by the simulation. Plus, the number of tasks represented in the Dask task graph will be of the same order of magnitude as the number of chunks. The same node will be in charge of scheduling all these tasks, and retrieving their results.

For big simulations running on hundreds of nodes, the head node would have to process tens of thousands of references and tasks at each iteration, which is too costly. @performance-naive-method demonstrates this. In this experiment, Doreisa is asked to compute the mean of a distributed array. The total number of chunks in this array is equal to the number of cores available in the cluster, so it is directly proportional to the number of nodes. With a well-parallelised system, one would expect the execution time to only slightly increase with the number of nodes (weak scaling). However, this is not the case here: the execution time is proportional to the number of nodes. In this situation, the centralized actor is clearly the bottleneck. More precisely, the analysis is composed of the following main parts:
  - Collecting the `ObjectRefs` produced by the workers.
  - Creating the Dask array as well as the task graph. For such small graphs, the time is negligible.
  - Executing the task graph using the Dask-on-Ray scheduler.
Both the reference gathering and the task graph execution are time-consuming processes, with neither being negligible relative to the other. To achieve a high-performance system, it is essential to optimize both aspects.

#figure(
    image("resources/exp-01.svg", width: 105%),
    caption: [Performance of the naive method (weak scaling with a simple analysis)],
) <performance-naive-method>

== Building the Dask Aray <collecting-references>

At each iteration of the simulation, MPI processes produce data stored in numpy arrays. These chunks of data are placed in Ray's object store, and references to them must be sent to the head node to allow it to build a full Dask array. A first approach simply consists of having all the MPI processes send their reference to the head node directly. However, this centralized approach is not scalable enough: gathering tens of thousands of references is a costly operation that can't be performed by a single process in a reasonable time, as a lot of communications are involved. Indeed, as shown in @ref-collecting-bench (explained below), when many processes send their references one-by-one, at most around one thousand references can be collected each second. The exact value will depend on many factors, but it is not enough for our applications.

To solve this problem, a simple idea consists of sending first the references to intermediate actors that will have the responsibility to collect a few of them, and send them to the head node in a single message. To see how well sending the references by group helps improving the performance, a simple setup is used. Some "simulation" processes generate numpy arrays and send references to them to the head node. The arrays are generated randomly, no simulation code is actually used. The process is repeated with a varying number of processes from 1 to 512, as well as a number of references sent by each process at each iteration varying from 1 to 256. During each measurement, 200 iterations are performed.

To avoid having to deploy the experiment on a very large cluster, several simulation scripts were started on each core. The measurement is repeated two times: one time with two simulation nodes, the other with four simulation nodes. The goal of this step is to make sure that the bottleneck actually comes from the head node and not the simulation node: it is the case if the results in these two configurations are similar. This is indeed the case: the total execution time of each scenario varies by less than 10% in the two cases. As having twice more nodes for the same task doesn't reduce the execution time, the bottleneck is indeed the head node, as expected.

This experiment was performed on the _gros_ cluster of the Nancy site of Grid5000. The exact specifications are available online at #link("https://www.grid5000.fr/w/Nancy:Hardware#gros").

#figure(
    image("resources/ref-collecting-bench.png", width: 105%),
    caption: [Time (ms) needed to collect a reference depending on the number of processes and references sent by each process],
) <ref-collecting-bench>

@ref-collecting-bench shows, for various number of processes and references sent by process, the time needed to send one reference.

First, we can notice that the measured values are higher when less than 8 processes are used. This is expected: with a small number of processes, the measured time includes some time where, for instance, the head node is idle, waiting for data. These measurements do not correspond to a realistic use case, as HPC simulations involve a much higher number of processes. When more processes are sending data to the head node, their number doesn't matter anymore and the measured values stabilize. In the next paragraph, we will focus on the results obtained with at least 8 processes.

With at least 8 processes, the total number of processes doesn't impact the time needed to send one reference. However, sending several references at each request greatly reduces the time needed to send one reference: it becomes possible to reduce the total time by around 20 times with this optimization.

In practice, to avoid useless network use, a good compromise is to place an actor on each simulation node. This actor has the responsibility to collect all the references to arrays produced by the node, and to send them all at once to the head node. The goal of this optimization is not to have something optimal since this part is not critical to obtain good performance. It is simply to optimize it enough so that it does not become a bottleneck and slow down the whole computation.

To conclude, to reduce the time taken to collect all the `ObjectRef`, it is possible to use intermediate actors on each node to collect the references first, and send them in batches to the head node. However, in the end, this optimization wasn't integrated to Doreisa: the optimization presented in the following section adopted a different approach that makes sending all the `ObjectRefs` to the head node useless.

== Distributed scheduler

=== Design

The issue with the proof of concept of Doreisa is that the head node becomes the bottleneck of the whole system when too many nodes are added to the cluster. It has the responsibility to communicate with all the workers to collect the references to the chunks, build the Dask array, schedule all the tasks...

As shown in @collecting-references, it is possible to reduce the time taken to collect all the references from the worker processes. Unfortunately, it doesn't solve the problem of executing the tasks: the head node still needs to create all the Ray tasks, which is costly for large task graphs.

This section describes a method to distribute the scheduling of the tasks; taking advantage of Ray's distributed scheduler. The goal is to avoid forcing the head node to communicate with all the data-producing processes as well as the worker processes, but instead limit the communication to lightweight messages with an actor running on each simulation node.

#place(
  auto,
  scope: "parent",
  float: true,
  [
    #figure(
      image("resources/doreisa-distributed-scheduler.png", width: 90%),
      caption: [Architecture of the Doreisa distributed scheduler],
    ) <doreisa-distributed-scheduler>
  ],
)

@doreisa-distributed-scheduler shows the architecture of the Doreisa distributed scheduler. The main difference with the proof-of-concept version is that an additional actor -- that we will call a `SchedulingActor` -- is started on each simulation node. The head actor will only communicate with the simulation nodes using this actor. This actor has the responsibility to collect all the `ObjectRefs` produced by the simulation nodes, and schedule the tasks sent by the head node.

The steps of one iteration of the analysis are as follow:
  1. As before, the simulation processes make some chunks of data available to Doreisa using PDI.
  2. The chunks are put in the Ray object store, and the `ObjectRefs` are collected. 
  3. When all the chunks of the node are ready, the head actor is notified.
  4. Once all the simulation nodes are ready, a Dask array is built and made available to the user. This array doesn't contain the `ObjectRefs` pointing to the data directly: for performance reasons, they are replaced by a small object indicating which object reference should be used.
  5. The user performs some computations on the Dask array, which produces a task graph. The task graph is passed to the Doreisa scheduler.
  6. The Doreisa scheduler finds a partition the graph, creating one partition for each simulation node. The partitions are sent to the actors.
  7. After receiving the partitioned task graphs, the scheduling actors prepare its execution. They send messages to one another to collect the `ObjectRefs` that they are missing (these `ObjectRefs` correspond to tasks scheduled by another scheduling actor). The references are placed in the task graph directly, replacing the placeholder object.
  8. The scheduling actor sent their task graphs to the Dask-on-Ray scheduler for execution. The Dask-on-Ray scheduler will schedule the tasks using the local node's Ray scheduler.

With this approach, all the simulation nodes are in charge of scheduling a part of the task graph, effectively distributing the scheduling.

=== An implementation detail

From an implementation perspective, there is one major difference compared to the proof-of-concept version: it is no longer possible to simply put `ObjectRefs` pointing to the data directly in the task graph that will be executed by the Dask-on-Ray scheduler. Indeed, as the scheduling is now distributed, a scheduling actor doesn't own all the `ObjectRefs` that are needed to perform the computation: it may need to ask other scheduling actors to send `ObjectRefs` corresponding to results of tasks that they scheduled. When asking another scheduling actor for an `ObjectRef`, it is not possible to directly get the actual `ObjectRef`, since it may not be ready at that time (all the actors are scheduling their tasks at the same time), and trying to get it anyway results in deadlocks.

For this reason, we actually need to use futures that will return the desired `ObjectRef`, that is... an `ObjectRef` of an `ObjectRef` of the actual data. However, the Dask-on-Ray scheduler doesn't work well with nested `ObjectRefs`: it expects the references to directly contain the data.

To solve this issue, it was necessary to:
  - Maintain the invariant that all the references are nested `ObjectRefs`, which sometimes requires artificially wrapping an `ObjectRef` inside another one.
  - Patch a small part of the Dask-on-Ray scheduler to make it work with nest `ObjectRefs`.

=== Evaluation

This new version of Doreisa was benchmarked on Jean Zay with up to 256 nodes in the cluster.

#figure(
    image("resources/exp-02.svg"),
    caption: [Time per iteration with the distributed scheduler (weak scaling, 40 chunks per node)],
) <distributed-scheduler-total-time-v0.1.5>

=== Graph partitioning strategy

The Doreisa distributed scheduler needs to partition the task graph in different subsets and send these subsets to the scheduling actors in the cluster.

The partitioning strategy has an impact on the performance of the application: if one scheduling actor has too many tasks to schedule, it can become a bottleneck similarly to what happened with the proof-of-concept version of Doreisa. If many directly dependent tasks are not put in the same partition, many messages will need to be exchanged between the scheduling actors to schedule the tasks. A good strategy needs to:
  - Produce a partition with subsets of a comparable size.
  - Minimize the number of dependencies between two tasks that are part of different subsets.

This section will determine the impact of the scheduling strategy on the performance of the system by comparing two partitioning strategies.

Note that the partitioning of the task graph only has an impact on which scheduling actor will have the responsibility to schedule each task. It is still the Ray scheduler of the node on which the scheduling actor runs will eventually be in charge of scheduling the task on any node of the cluster.

==== Considered strategies

Two partitioning strategies have been considered:

 - *Random partitioning.* Each task is randomly assigned to a scheduling actor, subject to the constraint that the resulting partition is balanced: the sizes of the subsets differ by at most one. This strategy doesn't try to minimize the number of dependencies from tasks in different subsets.
  #figure(
    image("resources/random-partitioning.png", width: 60%),
    caption: [Random task graph partitioning],
  ) <random-partitioning>

 - *Greedy partitioning.* A task $T$ is assigned to the scheduling actor that schedules the greatest number of tasks on which $T$ directly depends. This strategy is optimal on trees.
 #figure(
    image("resources/greedy-partitioning.png", width: 60%),
    caption: [Greedy task graph partitioning],
  ) <greedy-partitioning>

==== Evaluation

We evaluate the two strategies on a cluster composed of 32 simulation nodes and one head node. Each simulation node generates 40 very small chunks of data per iteration. The task consists of computing the mean of the Dask array.

In this situation, the task graph is a tree: leaf nodes are tasks computing the mean of each chunk, and inner nodes are tasks merging partial means together to compute the mean of a bigger block of the array (see @random-partitioning and @greedy-partitioning, squares correspond to chunks and circles to tasks).

#figure(
    image("resources/exp-04-graph-partitioning.svg", width: 100%),
    caption: [Performance impact of task graph partitioning],
  ) <graph-partitioning>

@graph-partitioning shows the time taken to complete the analytics using each graph partitioning strategy.

TODO analysis

Since the partitioning does not determine the nodes executing each task, since the communication cost between the actors is small and since all the communications happen in parallel, one could have expected the choice of the graph partitioning strategy to have a relatively small impact on the performance as long as the subsets of the partition have comparable sizes.

It is not completely clear why . Since the greedy partitioning algorithm works very well in real-life situations

=== Finding the bottleneck

As we saw in the previous section, the current system is able to scale well until about 64 nodes are added. Once this threeshold is reached, a new bottleneck appears and the execution time starts being proportional to the number of nodes in the Ray cluster.

To understand where this problem comes from, a more detailed analysis was realized. This experiment is named `03-TODO` in the `doreisa-internship` repository. The total execution time of a simple data analysis has been measured with a varying number of nodes: 10, 20, 40 and 80. This experiment has been realized on the `gros` cluster from `Grid5000`. The goal is to determine what are the parts of the process that take too much time, to identify the bottleneck. Four execution times are measured:

  1. Without performing any analysis at all. This is the time taken by the head node to receive the information by the scheduling actors that the chunks are ready, and to build the Dask array as well as the task graph.
  2. Executing the scheduling algorithm without sending the task graph to the scheduling actors. In addition to the previous step, each node of the task graph is assigned to a scheduling actor.
  3. Executing the scheduling algorithm and sending the task graph to the scheduling actors, without having the actors perform any computation at all. In addition to the previous step, the information about the tasks and the scheduling are sent to the scheduling actors.
  4. Performing all the computations required for the analysis. The scheduling actors actually run the computation.

#figure(
    image("resources/exp-03-time-per-action.svg"),
    caption: [Time per iteration per action],
) <exp-03-time-per-action>

#figure(
    image("resources/exp-03-time-for-cluster-size.svg"),
    caption: [Decomposition of the time per iteration depending on the cluster size],
) <exp-03-time-for-cluster-size>

@exp-03-time-per-action shows the time per iteration for these four parts of the analytics, and @exp-03-time-for-cluster-size shows, for each cluster size, the proportion of the time spent in each phase of the computation. (TODO: delete @exp-03-time-per-action ?)

First, we can notice that the distributed scheduler designed in the previous section scales very well: the execution time per iteration only slightly increase by a constant amont each time the cluster size doubles.

The high execution times for the bigger cluster sizes come from the first three tasks, which were negligible in smaller runs. To further optimize the system, we need to focus on them.

== Iteration preparation

=== Presentation

Thanks to the previous improvements, we managed to make the performance of Doreisa acceptable in most situations. Even with a large number of nodes in the cluster, an iteration takes less than one second to be executed. However, we might want to further reduce this latency to make the system work well with even more chunks per node, even faster.

Since the tasks that need to be performed (task graph partitioning, scheduling, etc) are already quite optimized, the idea is now to hide the time taken to execute these tasks by executing them in advance, before the data is available.

We will let the user define the tasks that will need to be performed a few iterations before the data is actually available by letting them define an optional callback, called a few iterations before the data is actually available. The Doreisa scheduler is then able to immediately start shipping the task graphs to the scheduling actors, without having to wait for the data to be ready. The user can prepare several iterations in parallel, so that the preparation of iterations is never a bottleneck. The tasks will start being executed as soon as the data is available, and the user will be able retrieve and use the results from the standard callback.

This mechanism relies on Dask's persist API: instead of calling the `compute` method that executes the computation and returns its result, the `persist` method starts the computation in the background and returns a Dask array containing a futures to the final result. The Doreisa scheduler needed to be updated to support this feature: if the scheduler is called from a `persist` call, it directly returns `ObjectRefs` to the final result, without getting their value.

=== User API

@prepare-iteration-listing shows what the iteration preparation interface looks like from a user perspective: the user defines a standard callback as well as a preparation callback. The return value of the preparation callback is passed as an argument to the simulation callback.

#place(
  auto,
  scope: "parent",
  float: true,
  [#figure(
    text(0.8em)[
      ```python
      def prepare_iteration(array: da.Array, *, timestep: int) -> da.Array:
          # We can't use compute here since the data is not available yet
          return array.sum().persist()

      def simulation_callback(array: da.Array, *, timestep: int, preparation_result: da.Array):
          print(preparation_result.compute())

      run_simulation(
          simulation_callback,
          [ArrayDefinition("array")],
          max_iterations=NB_ITERATIONS,
          prepare_iteration=prepare_iteration,
          preparation_advance=10,
      )
      ```
    ],
    caption: [Iteration preparation example],
  ) <prepare-iteration-listing>]
)

=== Performance evaluation

#figure(
    image("resources/exp-03.svg", width: 105%),
    caption: [Performance improvement of iteration preparation],
) <perfs-detail>

==== Varying the number of nodes

The performance improvement of the iteration preparation mechanism is evaluated with the same protocol as before: the number of nodes varies with a constant number of chunks per node, and the mean time per iteration is measured. The experiment is repeated five time, with a number of iterations prepared in advance varying from 0 to 8.

#figure(
    image("resources/exp-03-preparation-advance.svg", width: 105%),
    caption: [Performance improvement of iteration preparation: varying number of iterations prepared in advance],
) <perfs-iteration-preparation>

@perfs-iteration-preparation shows the results obtained with this experiment. When no iterations are prepared in advance (which approximately corresponds to not using the preparation mechanism), the execution time ultimately starts increasing linearly with the number of nodes.

As we increase the number of iterations prepared in advance, we notice that the execution time becomes smaller. When enough iterations are prepared, the expensive scheduling tasks stop being a bottleneck and the performance stops improving.

==== Varying the number of chunks per node

More importantly, if enough iterations are prepared in advance, the execution time no longer depends on the number of chunks per node.

== _In transit_ analytics

Until now, the simulation nodes of the cluster were also in charge of analysing the data. Performing the analysis _in situ_ -- directly on the machine producing the data -- can be a good solution, especially in situations where the simulation code runs on the GPU of the machine. In this case, it usually lets CPU cores idle, so they can be used by the analytics without overhead.

However, some simulations run only on CPU, and performing the analysis of the data on the simulation nodes would disturb it in an unacceptable manner. _In transfer_ analytic helps solving this problem by making simulation processes send their data to other machines dedicated to the analysis. The simulation is only paused during the time the data is sent to the analytics machines, and can resume while the analysis is ongoing.

#place(
  auto,
  scope: "parent",
  float: true,
  [
    #figure(
      image("resources/doreisa-in-transit.png", width: 90%),
      caption: [Architecture of the Doreisa for _in-transit_ analytics],
    ) <doreisa-in-transit>
  ],
)

@doreisa-in-transit shows how Doreisa works for _in transit_ analytics. It is similar to _in situ_ analytics previously introduced, with an important difference: simulation nodes send all their data to analytic nodes. The analytic nodes will write the data to their Ray object store, and then use it as for _in situ_ analytics.

Ray can be quite heavy to start on a machine, with several processes needed: the raylet, the plasma store, the workers, etc. To avoid disturbing the simulation, in the case of _in transit_ analytics, Ray is not started at all on simulation nodes. The simulation processes are simply given an IP address and a port that they use to communicate (ie get the preprocessing callbacks and send the chunks of data) with the analytic node using #smallcaps[ZeroMQ] @zmq.

The chunks of data are sent using #smallcaps[ZeroMQ] over a TCP connection, which prevents taking full advantage of the high-performance network available on the supercomputer. An improvement could be to take advantage of RDMA (Remote Direct Memory Access) to send the data more efficiently.

== Conclusion

Thanks to the various improvements presented in the previous sections, Doreisa became a system able to execute task graphs containing tens of thousands of tasks on clusters composed of hundreds of nodes, with very good performance.

In this section, we focused on improving the number of tasks scheduled per second, as this is probably the most important limitation of previous approaches.

The following section will evaluate the performance of Doreisa in more various scenarios, closer to real-life applications.

= Performance evaluation <performance-evaluation>

== Bigger chunks

All the experiments presented in the previous section were realized using chunks of data with a negligible size, to avoid having the effective computation influence the results. In this section, Doreisa is evaluated performing an analysis on an array composed of a varying number of $1000 times 10000$ chunks (40 chunks per node in the cluster). The analysis is also more expensive: we compute the mean of the values obtained after calling the function $x mapsto sin(sqrt(x+1))$ element-wise.

#figure(
    image("resources/exp-06.svg", width: 90%),
    caption: [Analysis with big chunks of data],
) <big-chunks-eval>

The results are shown in @big-chunks-eval. We can notice that the overhead introduced by Doreisa is negligible compared to the effective computation time.

The experiment was realized before the development of the iteration preparation mechanism. With this optimization, the Doreisa overhead could be further reduced.

== Forced data movements

For some computations, it is impossible to perform all the computations directly where the data is produced, and data movements are required. Consider the task of computing the sum of the coefficients of $M + f(M)$, where $f(M)$ is M flipped on its first axis.

While this computation could technically be further optimized, Dask is not able to as shown on the task graph corresponding to this computation for an array with $3 times 1$ chunks, represented in @flip-sum-task-graph.

#figure(
    image("resources/flip-sum-task-graph.png", width: 50%),
    caption: [Task graph of a computation requiring data movements],
) <flip-sum-task-graph>

@big-chunks-eval-data-movements shows the time taken to perform this computation with a chunk shape of $40 N times 1$, where $N$ is the number of nodes in the cluster. We can notice that due to the data movements required, each iteration takes more time than before, even if the actual computation is far simpler.

#figure(
    image("resources/exp-06-data-movements.svg", width: 90%),
    caption: [Analysis with big chunks of data, data movements required],
) <big-chunks-eval-data-movements>

Even if the total amount of transmitted data per iteration is proportional to the number of nodes in the cluster, the time per iteration doesn't grow: the high-performance network connecting the nodes of the supercomputer is performant enough not to become a bottleneck.

== Integration with Parflow

The integration with Parflow was realized by Andrès Bermeo Marinelli, engineer in the team.

= Technical details

== Software Engineering practices

This project follows :

  - All the aspects of the implementation are tested. The tests are executed automatically on Github at each pull-request and on the main branch.
  - 
  - Releases are published regularly on PyPI.


= Challenges <challenges>

== Technical issues

During the development of Doreisa, I came across several problems that took me a lot of time to fully understand and solve. This section briefly describes some of them.

 - *Deployement on SLURM.* Supercomputers typically rely on SLURM @slurm to manage their resources. To use Doreisa on such supercomputers, it was necessary to start a Ray cluster with SLURM. When it is starting on a node, Ray starts the worker processes that will be used to execute remote tasks. The number of such processes corresponds to the number of available cores (TODO threads?) on the machine. Since supercomputers are optimized for efficient computations, each machine typically has several CPUs, each one having tens of cores. As a consequence, a lot of Ray workers can be started at the same time (TODO 40 or 80 for Jean Zay). Each of these processes performs operations on Numpy arrays. Numpy internally relies on OpenBLAS, which itself starts many threads to take advantage of the parallelism offered by the machine. This high number of threads made SLURM kill Ray processes.


= Conclusion


= Acknowledgments

Experiments presented in this paper were carried out using the Grid'5000 testbed, supported by a scientific interest group hosted by Inria and including CNRS, RENATER and several Universities as well as other organizations (see https://www.grid5000.fr).


#bibliography("bibliography.bib", style: "ieee")
