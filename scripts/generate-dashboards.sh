#!/bin/bash
set -uo pipefail

DASHBOARDS_DIR="dashboards"
OUTPUT_DIR="generated-dashboards"
VENDOR_DIR="vendor"

# Create output directory if it doesn't exist
mkdir -p "${OUTPUT_DIR}"

# Find all .libsonnet files in dashboards directory (exclude -copy files)
find "${DASHBOARDS_DIR}" -name "*.libsonnet" -type f ! -name "*-copy.libsonnet" | while read -r libsonnet_file; do
  # Import the libsonnet file and extract all dashboards from grafanaDashboards
  # Skip files that don't have grafanaDashboards or have empty grafanaDashboards (library files)
  dashboard_json=$(jsonnet -J "${VENDOR_DIR}" -J . -e "
    local dashboard = import '${libsonnet_file}';
    dashboard.grafanaDashboards
  " 2>/dev/null) || continue
  
  # Check if grafanaDashboards exists and is not empty
  if [ -z "$dashboard_json" ] || [ "$dashboard_json" = "{}" ] || [ "$dashboard_json" = "null" ]; then
    continue
  fi
  
  # Process each dashboard in grafanaDashboards
  echo "$dashboard_json" | jq -c 'to_entries[]' 2>/dev/null | while read -r entry; do
    if [ -n "$entry" ]; then
      filename=$(echo "${entry}" | jq -r '.key')
      dashboard_content=$(echo "${entry}" | jq -c '.value')
      output_file="${OUTPUT_DIR}/${filename}"
      echo "${dashboard_content}" | jq '.' > "${output_file}"
      echo "Generated: ${output_file}"
    fi
  done
done

echo "All dashboards generated successfully in ${OUTPUT_DIR}/"
