#!/bin/bash
#SBATCH --job-name=doreisa_test

#SBATCH --time=00:02:00
#SBATCH --output=job-%j.out
#SBATCH --error=job-%j.err

module purge

module load python/3.12.7

# Add Ray to the PATH
export PATH="/linkhome/rech/genlig01/ufw76xj/.local/bin:$PATH"

export OPENBLAS_NUM_THREADS=1

# Create directories for results
mkdir -p timesteps

# Find the head and worker nodes
scontrol show hostnames $SLURM_JOB_NODELIST > nodes.txt
head -n 1 nodes.txt > headnode.txt
tail -n +2 nodes.txt > workernodes.txt

headnode=$(cat headnode.txt)
workernodes=$(cat workernodes.txt | tr '\n' ',' | sed 's/,$//')

# Find the IP of the head node. We use ib0 for the InfiniBand interface.
head_node_ip=$(srun --nodes=1 --nodelist=$headnode --ntasks-per-node=1 bash -c 'ip -o -4 addr show ib0 | awk "{print \$4}" | cut -d/ -f1')
echo "Head node IP: $head_node_ip"

# Start the head node
srun --nodes=1 --nodelist=$headnode --ntasks=1 --cpus-per-task=40 bash -c "
    ulimit -n 65535
    export OPENBLAS_NUM_THREADS=1
    ray start --head --node-ip-address=$head_node_ip --port=4242 --disable-usage-stats
    sleep 10
    python3 head.py 1
" &

sleep 30

echo "Head node started"

mapfile -t nodes < workernodes.txt

iNode=0
for node in "${nodes[@]}"; do
    echo "Starting node $node"

    # On Jean Zay, we are allowed to start at most 96 processes per
    # node (see slurm.conf). We need to be careful not to exceed this limit.
    # TODO start more workers per node after updating doreisa.
    srun --nodes=1 --nodelist=$node --ntasks=1 --cpus-per-task=40 bash -c "
        ulimit -n 65535
        export OPENBLAS_NUM_THREADS=1
        node_ip=\$(ip -o -4 addr show ib0 | awk \"{print \\\$4}\" | cut -d/ -f1)
        echo \"Node IP: \$node_ip\"
        ray start --address=$head_node_ip:4242 --node-ip-address=\$node_ip
        sleep 10
        ray status
        for i in \$(seq $((20 * iNode)) $((20 * (iNode+1) - 1))); do
            python3 worker.py \$i $((20 * (SLURM_NNODES-1))) 20 &
        done
        wait
    " &

    iNode=$((iNode + 1))
done

echo "All workers started"

wait
