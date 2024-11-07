#!/bin/bash

S3_BUCKET_NAME="backupeksclusterymlfile"

current_date=$(date +%Y-%m-%d)

namespaces=(
    "webhttp"
    "adaptor-assessment-api"
    "adaptor-commonutil-api"
    "adaptor-communication-api"
    "adaptor-integration-api"
    "adaptor-patients-api"
    "adaptor-pgi-api"
    "adaptor-task-api"
    "adaptor-users-api"
    "exp-appointhttps-api"
    "exp-appointment-api"
    "exp-assessment-api"
    "exp-commonutil-api"
    "exp-patient-api"
    "exp-pgi-api"
    "exp-task-api"
    "exp-users-api"
)

backup_dir="./k8s-backup-${current_date}"
mkdir -p "$backup_dir"

for ns in "${namespaces[@]}"; do
    backup_file="${backup_dir}/${ns}-backup-${current_date}.yaml"
    kubectl get all --namespace "$ns" -o yaml > "$backup_file"
    aws s3 cp "$backup_file" "s3://$S3_BUCKET_NAME/$current_date/${ns}-backup-${current_date}.yaml"
done

