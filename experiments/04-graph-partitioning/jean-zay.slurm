#!/bin/bash
#SBATCH --job-name=doreisa_test

#SBATCH --time=00:10:00
#SBATCH --output=job-%j.out
#SBATCH --error=job-%j.err

module purge

module load python/3.12.7

CHUNKS_PER_NODE=40

# Add Ray to the PATH
export PATH="/linkhome/rech/genlig01/ufw76xj/.local/bin:$PATH"

export OPENBLAS_NUM_THREADS=1

# Create directories for results
mkdir -p timesteps perfs

# Find the head and worker nodes
scontrol show hostnames $SLURM_JOB_NODELIST > nodes.txt
head -n 1 nodes.txt > headnode.txt
tail -n +2 nodes.txt > workernodes.txt

headnode=$(cat headnode.txt)
mapfile -t nodes < workernodes.txt

# Find the IP of the head node. We use ib0 for the InfiniBand interface.
head_node_ip=$(srun --nodes=1 --nodelist=$headnode --ntasks-per-node=1 bash -c 'ip -o -4 addr show ib0 | awk "{print \$4}" | cut -d/ -f1')
echo "Head node IP: $head_node_ip"

# Generate a random ID
file_ready="head-node-ready-$RANDOM-$RANDOM-$RANDOM"

# Start the head node
srun --nodes=1 --nodelist=$headnode --ntasks=1 --cpus-per-task=40 bash -c "
    ulimit -n 65535
    export OPENBLAS_NUM_THREADS=1
    export RAY_worker_register_timeout_seconds=240
    ray start --head --node-ip-address=$head_node_ip --port=4242 --disable-usage-stats --include-dashboard=false
    sleep 10
    touch $file_ready
    python3 head.py
" &

while [ ! -f $file_ready ]; do
    sleep 1
done
rm $file_ready

sleep 10

echo "Head node started"

iNode=0
for node in "${nodes[@]}"; do
    echo "Starting node $node"

    # On Jean Zay, we are allowed to start at most 96 processes per
    # node (see slurm.conf). We need to be careful not to exceed this limit.
    srun --nodes=1 --nodelist=$node --ntasks=1 --cpus-per-task=40 bash -c "
        ulimit -n 65535
        export OPENBLAS_NUM_THREADS=1
        export RAY_worker_register_timeout_seconds=240
        node_ip=\$(ip -o -4 addr show ib0 | awk \"{print \\\$4}\" | cut -d/ -f1)
        echo \"Node IP: \$node_ip\"
        ray start --address=$head_node_ip:4242 --node-ip-address=\$node_ip
        sleep 10
        ray status
        for i in \$(seq $((CHUNKS_PER_NODE * iNode)) $((CHUNKS_PER_NODE * (iNode+1) - 1))); do
            python3 worker.py \$i $((CHUNKS_PER_NODE * (SLURM_NNODES-1))) $CHUNKS_PER_NODE &
        done
        wait
    " &

    iNode=$((iNode + 1))
done

echo "All workers started"

wait
