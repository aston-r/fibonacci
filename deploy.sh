#!/bin/bash

# Fail on any '$? > 0'
set -o errexit

# Constants
DOCKER_HUB_ACCOUNT='yevhenlodovyi'
PROJECT_NAME='fibonacci'

# Functions
function usage() {
  echo """
Usage: $0 [--publish|--deploy|]

Args:
--publish: Publish Docker image into registry
--deploy: Deploy k8s configuration
"""
exit 0
}

# Main part
opts="$(getopt -o '' -l 'publish,deploy,help' -- "$@")"
eval set -- "${opts}"

while true; do
  case "${1}" in
    '--publish') publish='Y'; shift 1;;
    '--deploy') deploy='Y'; shift 1;;
    '--help') usage;;
    '--') shift; break ;;
    *) break ;;
  esac
done

# Build and ulpload images to docker registry
subdirs="$(find . -maxdepth 2 -type f -name Dockerfile -exec dirname {} \; | xargs -I {} basename {})"
for subdir in ${subdirs}; do
    tag_prefix="${DOCKER_HUB_ACCOUNT}/${PROJECT_NAME}-${subdir}"
    echo "Building '${tag_prefix}' image to registry..."
    docker build -t "${tag_prefix}:latest" \
                 -t "${tag_prefix}:${GIT_SHA}" \
                 "${subdir}"
    if [[ "${publish}" == 'Y']]; then
        echo "Uploading '${tag_prefix}' to registry..."
        docker push "${tag_prefix}:latest"
        docker push "${tag_prefix}:${GIT_SHA}"
    fi
done

# Deploy k8s
if [[ "${deploy}" == 'Y' ]]; then
    echo 'Deploying k8s configuration...'
    kubectl apply -f k8s
    # Force deployments to re-pull an image
    # TODO:check if there is more convinient way:
    # https://github.com/kubernetes/kubernetes/issues/33664
    for subdir in ${subdirs}; do
        kubectl set image deployments/${subdir}-deployment \
                    ${subdir}="${DOCKER_HUB_ACCOUNT}/${PROJECT_NAME}-${subdir}:${GIT_SHA}"
    done
fi
