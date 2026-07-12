#!/usr/bin/env bash
set -eu

GCLOUD=/home/wizard/google-cloud-sdk/bin/gcloud
PROJECT=k8s-cluster-502109

# gcloud CLI commands can reuse the ADC token via this env var,
# avoiding a second interactive `gcloud auth login`
export CLOUDSDK_AUTH_ACCESS_TOKEN="$($GCLOUD auth application-default print-access-token)"

$GCLOUD services enable compute.googleapis.com --project "$PROJECT"
echo "API_ENABLED"
$GCLOUD services list --enabled --project "$PROJECT" --filter="name:compute" 2>/dev/null | tail -2
