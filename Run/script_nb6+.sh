#!/bin/bash

###Jobanme
#SBATCH -J nb6++nt

#SBATCH --nodes=1
#SBATCH --ntasks-per-node=4

#SBATCH --mem=4000mb
#SBATCH --time=160:00:00
#SBATCH --gres=gpu:a100:1
#SBATCH --account=oz003

###Names for error and output files, %J job number, change as you like
#SBATCH --error=job.%J.err
#SBATCH --output=job.%J.out

module load gcc/11.3.0
module load openmpi/4.1.4
module load cuda/11.7.0

###ulimit -s 20480
ulimit -s unlimited

export OMP_NUM_THREADS=4
export GPU_LIST="0"

./nbody6++.sse.gpu < N100k.inp.new 1> logfile 2> errfile


