# Kubernetes EKS Job Monitor

This script allows you to monitor the transition of jobs from the default cluster to an Amazon EKS cluster. It fetches job data from `prow.k8s.io`, a Kubernetes job dashboard, and performs various operations like checking all jobs in the EKS cluster, calculating the average duration of successful runs of jobs, and reporting significant variations. It also tracks the transition progress of jobs from the default cluster to the EKS cluster.

## Usage

This script accepts two options:

1. `-c`: Check all EKS jobs. It will calculate the average duration of the last five successful runs of each job, and compare that to the duration of the most recent run. If the most recent run's duration is more than 10% shorter or longer than the average duration, it will print out a message asking you to update the job.
1. `-p`: Check the progress of the transition from the default cluster to the EKS cluster. It will calculate the number of jobs that are running in each cluster, and print out a message showing how many jobs have been transitioned.

You can run the script with either option like so:

```bash
./script.sh -c
```
or

```bash
./script.sh -p
```

## Dependencies

This script uses `bash`, `curl`, and `jq` to fetch and process the data. Make sure you have these installed before running the script.
