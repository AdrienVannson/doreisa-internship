#!/bin/bash
#SBATCH --job-name=doreisa_test
#SBATCH --nodes=3

#SBATCH --time=00:01:00
#SBATCH --output=job-%j.err
#SBATCH --error=job-%j.out

module purge

module load python/3.12.7

scontrol show hostnames $SLURM_JOB_NODELIST > nodes.txt
head -n 1 nodes.txt > headnode.txt
tail -n +2 nodes.txt > workernodes.txt

headnode=$(cat headnode.txt)
workernodes=$(cat workernodes.txt | tr '\n' ',' | sed 's/,$//')

srun --nodes=1 --nodelist=$headnode python3 head.py &

srun --nodes=$((SLURM_JOB_NUM_NODES - 1)) --nodelist=$workernodes python3 worker.py $headnode &

wait
