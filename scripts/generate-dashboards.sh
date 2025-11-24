#!/bin/bash
set -euo pipefail

DASHBOARDS_DIR="dashboards"
OUTPUT_DIR="generated-dashboards"
VENDOR_DIR="vendor"

# Create output directory if it doesn't exist
mkdir -p "${OUTPUT_DIR}"

# Find all .libsonnet files in dashboards directory
find "${DASHBOARDS_DIR}" -name "*.libsonnet" -type f | while read -r libsonnet_file; do
  # Get the relative path from dashboards directory
  rel_path="${libsonnet_file#${DASHBOARDS_DIR}/}"
  base_name=$(basename "${libsonnet_file}" .libsonnet)
  
  # Import the libsonnet file and extract all dashboards from grafanaDashboards
  jsonnet -J "${VENDOR_DIR}" -J . -e "
    local dashboard = import '${libsonnet_file}';
    dashboard.grafanaDashboards
  " | jq -c 'to_entries[]' | while read -r entry; do
    filename=$(echo "${entry}" | jq -r '.key')
    dashboard_json=$(echo "${entry}" | jq -c '.value')
    output_file="${OUTPUT_DIR}/${filename}"
    echo "${dashboard_json}" | jq '.' > "${output_file}"
    echo "Generated: ${output_file}"
  done
done

echo "All dashboards generated successfully in ${OUTPUT_DIR}/"

