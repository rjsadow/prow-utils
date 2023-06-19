#!/bin/bash

# Check a specific job
check_job() {
  local repo=$1
  local job=$2
  local jobUrl="https://prow.k8s.io/job-history/gs/kubernetes-jenkins/pr-logs/directory/${job}"

  # Fetch job data from server and extract JSON
  local getJobData
  getJobData=$(curl -sk "${jobUrl}" || { echo "Error fetching job data"; exit 1; })
  local jobJson=$(echo "${getJobData}" | grep -o '\[{.*}\]' | sed 's/var allBuilds = //')

  # Extract the durations if the "Result" is "SUCCESS"
  local duration=$(echo "${jobJson}" | jq -r '.[] | select(.Result == "SUCCESS") | .Duration')

  # Read the durations into an array
  local durations
  IFS=$'\n' read -d '' -ra durations <<< "${duration}"

  # Extract the last 5 durations
  local lastFiveDurations=("${durations[@]: -5}")

  # If we have less than 5 durations, return early
  if [ "${#lastFiveDurations[@]}" -ne 5 ]; then
    return
  fi

  # Calculate the average of the last 5 durations
  local total=0
  for duration in "${lastFiveDurations[@]}"; do
    total=$((total + duration))
  done
  local average=$((total / ${#lastFiveDurations[@]}))

  # Check if the average is significantly different from the first value
  local firstValue=${durations[0]}
  local difference=$((average - firstValue))
  local percentageDifference=$((-$((difference * 100 / firstValue))))


  if ((percentageDifference >= 10)); then
    # Convert average value to minutes and seconds
    local averageMinutes=$((average / 60000000000))
    local averageSeconds=$((average / 1000000000 % 60))

    # Convert first value to minutes and seconds
    local firstValueMinutes=$((firstValue / 60000000000))
    local firstValueSeconds=$((firstValue / 1000000000 % 60))
    printf "%-50s %-16s %-16s %-12s %s\n" "$job" "Expected:${averageMinutes}m${averageSeconds}s" "Received:${firstValueMinutes}m${firstValueSeconds}s" "Off by:${percentageDifference}%" "Please update $repo"
  fi
}

fetch_all_jobs() {
  local cluster=$1
  local allJobs
  allJobs=$(curl -s https://prow.k8s.io/prowjobs.js | jq -r --arg cluster "$cluster" '.items[] | select(.spec.cluster == $cluster and .metadata.labels["prow.k8s.io/type"] == "presubmit") | "\(.metadata.labels["prow.k8s.io/refs.org"])/\(.metadata.labels["prow.k8s.io/refs.repo"]):\(.spec.job)"' | sort -u || { echo "Error fetching jobs"; exit 1; })
  echo "${allJobs}"
}

process_jobs() {
  local allJobs=$1
  local jobs
  IFS=$'\n' read -d '' -ra jobs <<< "${allJobs}"
  for job in "${jobs[@]}"; do
    local repo=$(echo "${job}" | cut -d':' -f1)
    local jobName=$(echo "${job}" | cut -d':' -f2)
    check_job "${repo}" "${jobName}"
  done
  echo "Finished checking ${#jobs[@]} jobs"
}

check_all_eks_jobs() {
  local allJobs=$(fetch_all_jobs "eks-prow-build-cluster")
  process_jobs "${allJobs}"
}

check_transition_progress() {
  local numOfEksJobs=$(fetch_all_jobs "eks-prow-build-cluster" | wc -w)
  local numOfDefaultJobs=$(fetch_all_jobs "default" | wc -w) 
  printf "Transitioned %s/%s presubmit jobs from default to the EKS cluster\n" "$numOfEksJobs" "$(($numOfDefaultJobs+${numOfEksJobs}))"
}

function abs() {
   if [ $1 -lt 0 ]; then
      echo $((-$1))
   else
      echo $1
   fi
}

# Main script
while getopts "cp" option; do
  case $option in
    c) check_all_eks_jobs ;;
    p) check_transition_progress;;
    *) echo "Invalid option" >&2 ;;
  esac
done