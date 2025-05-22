#!/bin/bash
#SBATCH --job-name=doreisa_test
#SBATCH --nodes=2

#SBATCH --time=00:05:00
#SBATCH --output=job-%j.out
#SBATCH --error=job-%j.err

module purge

module load python/3.12.7

# Create directories for results
mkdir -p timesteps

# Find the head and worker nodes
scontrol show hostnames $SLURM_JOB_NODELIST > nodes.txt
head -n 1 nodes.txt > headnode.txt
tail -n +2 nodes.txt > workernodes.txt

headnode=$(cat headnode.txt)
workernodes=$(cat workernodes.txt | tr '\n' ',' | sed 's/,$//')

# Start the head node
srun --nodes=1 --nodelist=$headnode --ntasks-per-node=1 ray start --head --port=4242 
srun --nodes=1 --nodelist=$headnode --ntasks-per-node=1 python3 head.py 1 &

sleep 5
echo "Head node started"

# Start the simulation nodes
srun --nodes=$((SLURM_JOB_NUM_NODES - 1)) --nodelist=$workernodes --ntasks-per-node=1 ray start --address=$headnode:4242

# Start the workers
echo "Starting the simulation"

srun --nodes=$((SLURM_JOB_NUM_NODES - 1)) --nodelist=$workernodes --ntasks-per-node=$SLURM_CPUS_ON_NODE python3 worker.py &

wait
