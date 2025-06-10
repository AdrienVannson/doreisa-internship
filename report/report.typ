#set document(author: "Adrien Vannson", title: "Internship report")

#set page(numbering: "1", number-align: center)
#set text(font: "New Computer Modern", lang: "en")
#set par(leading: 0.55em, first-line-indent: 1.8em, justify: true)
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

This Master thesis introduces a new way to process data coming from HPC simulations, easily and in a distributed and efficient manner. The proposed solution should be able to scale on supercomputers such as the Adastra and Jean Zay.

== Performance requirements

The proposed solution needs to scale well to some of the biggest supercomputers such as the french Adastra and Jean Zay.

Adastra is hosted by the _Centre Informatique National de l’Enseignement Supérieur (CINES)_ in Montpellier. In November 2024, it was ranked \#30 in Top500, with an Rmax value of 46.10 PFlop/s. In addition to login and pre/post processing nodes, Adastra is equiped with 544 scalar nodes, and . The detailed specification is available on Adasta's website @adastra.

Jean Zay is . In November 2024, it was ranked \#27 in Top500, with an Rmax value of 52.18 PFlop/s.

Given the architecture of these supercomputers, Doreisa should be able to scale to systems having thousands of nodes, producing tens of thousands to potentially hundreds of thousands of chunks of data per iteration.

= State of the art

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

See @exoshuffle

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

= Design of Doreisa

== First proof of concept

=== Design

The general design of the first proof of concept of Doreisa is shown in figure @doreisa-poc.

#figure(
    image("resources/doreisa-poc.png", width: 105%),
    caption: [Architecture of the first Doreisa proof of concept],
) <doreisa-poc>

Each step of the analysis pipeline consists of the following steps:

  1. The MPI processes terminate their simulation. The data is ready for analytics. It is made available to Doreisa using PDI, which serves here as an interface between Doreisa and the simulation code.
  2. The data produced by the simulation is placed in the Ray object store. An ObjectRef is produced: this reference to the data is sent to a main actor running on the head node.
  3. The head actor collects the references of all the processes. Once it has received all of them, it builds a Dask array from it.
  4. The user script receives the Dask array. The array can be used as a standard Dask array, to perform any kind of analysis. Performing operations on the Dask array produces a task graph.
  5. The task graph is passed to the Dask-on-Ray scheduler that is in charge of executing it. Each Dask task is converted to a Ray task, and scheduled by Ray. Ray takes into account data locality when scheduling tasks, so unnecessary data movements should be avoided.

=== Performance evaluation

This first solution has the drawback of being really centralized: the head actor need to collect an ObjectRef for each chunk produced by the simulation. Plus, the number of tasks represented in the Dask task graph will be of the same order of magnitude as the number of chunks. The same node will be in charge of scheduling all these tasks, and retrieving their results.

For big simulations running on hundreds of nodes, the head node would have to process tens of thousands of references and tasks at each iteration, which is too costly, as shown on Figure XXX demonstrates this.

== Building the Dask Aray

At each iteration of the simulation, MPI processes produce data stored in numpy arrays. These chunks of data are placed in Ray's object store, and references to them must be sent to the head node to allow it to build a full Dask array. A first approach simply consists of having all the MPI processes send their reference to the head node directly. However, this centralized approach is not scalable enough: gathering tens of thousands of references is a costly operation that can't be performed by a single process in a resonable time, as a lot of communications are involved. Indeed, as shown in @ref-collecting-bench (explained bellow), when many processes send their references one-by-one, at most around one thousand references can be collected each second. The exact value will of course depend on the hardware, but it is one order of magnitude bellow the target scale.

To solve this problem, a simple idea consists of sending first the references to intermediate actors, that will have the responsability to collect a few of them, and send later to the head node in a single message. The following experiment measure the time needed to collect all the references, either naively or with this optimization.

To verify this and see how well sending the references by group helps improving the performance, a simple setup is used. Some "simulation" processes generate numpy arrays and send references to them to the head node. The arrays are generated randomly, no simulation code is actually used in this simple setup. The process is repeated with a varying number of processes from 1 to 512, as well as a number of references sent by each process at each iteration varying from 1 to 256. During each measurement, 200 iterations of the process are performed.

To avoid having to deploy the experiment on a very large cluster, several simulation scripts were started on each core. The measurement is repeated two times: one time with two simulation nodes, the other with four simulation nodes. The goal of this step is to make sure that the bottleneck actually comes from the head node and not the simulation node: it is the case if the results in these two configurations are similar. This is indeed the case: the total execution time of each scenario varies by less than 10% in the two cases. As having twice more nodes for the same task doesn't reduce the execution time, the bottleneck is indeed the head node, as expected.

This experiment was perform on the _gros_ cluster of the Nancy site of Grid5000. The exact specifications are available online at #link("https://www.grid5000.fr/w/Nancy:Hardware#gros").

#figure(
    image("resources/ref-collecting-bench.png", width: 105%),
    caption: [Time (ms) needed to collect a reference depending on the number of processes and references sent by each process],
) <ref-collecting-bench>

@ref-collecting-bench shows, for various number of processes and references sent by process, the time needed to send one reference.

First, we can notice that the measured values are higher when less than 8 processes are used. This is expected: with a small number of processes, the measured time includes some time where, for instance, the head node is idle, waiting for data. This measurements do not corespond to a realistic use case, as simulations HPC simulations involve a much higher number of processes. When more processes are sending data to the head node, their number doesn't matter anymore and the measured values stabilize. In the next paragraph, we will focus on the results obtained with at least 8 processes.

With at least 8 processes, the total number of processes doesn't impact the time needed to send one reference. However, sending several references at each request greatly reduce the time needed to send one reference: it becomes possible to reduce the total time by around 20 times with this optimization.

In practice, to avoid useless network use, a good compromise is to place an actor on each simulation node. This actor has the responsability to collect all the references to arrays produced by the node, and to send them all at once to the head node. The goal of this optimization is not to have something optimal since this part is not critical to obtain good performance. It is simply to optimize it enough so that it does not become a bottleneck and slow down the whole computation.

#figure(
    image("resources/results-method-1.png", width: 107%),
    caption: [Performance of the first method],
)

== Decentralized scheduler

== Evaluation (TODO titre)

As we saw in the previous section, the current system is able to scale well until about TODO nodes are added. Once this threeshold is reached, a new bottleneck appears and the execution time starts being proportionnal to the number of nodes in the Ray cluster.

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


= Scalability

This project aims at being used in large scale high-performance computations. It needs to scale properly to simulations involving hundreds of thousands to millions of cores. This has a strong impact on the architectural choices.

== Centralized approach

A first approach consists of having a central node that gather the references to numpy arrays sent by all the workers. Once all the references have been received, it becomes possible to use them to build a Dask Array. This centralized approach is not scalable enough: gathering the references is a costly operation as it requires to communicate with the workers.


= Performance evaluation


= Challenges

= Technical issues

During the development of Doreisa, I came across several problems that took me a lot of time to fully understand and solve. This section briefly describes some of them.

 - *Deployement on SLURM.* Supercomputers typically rely on SLURM @slurm to manage their resources. To use Doreisa on such supercomputers, it was necessary to start a Ray cluster with SLURM. When it is starting on a node, Ray starts the worker processes that will be used to execute remote tasks. The number of such processes corresponds to the number of available cores (TODO threads?) on the machine. Since supercomputers are optimized for efficient computations, each machine typically has several CPUs, each one having tens of cores. As a consequence, a lot of Ray workers can be started at the same time (TODO 40 or 80 for Jean Zay). Each of these processes performs operations on Numpy arrays. Numpy internally relies on OpenBLAS, which itself starts many threads to take advantage of the parallelism offered by the machine. This high number of threads made SLURM kill Ray processes.


= Conclusion


= Acknowledgments

Experiments presented in this paper were carried out using the Grid'5000 testbed, supported by a scientific interest group hosted by Inria and including CNRS, RENATER and several Universities as well as other organizations (see https://www.grid5000.fr).


#bibliography("bibliography.bib", style: "ieee")
