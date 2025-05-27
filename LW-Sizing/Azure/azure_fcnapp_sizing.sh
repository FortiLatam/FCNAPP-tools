#!/bin/bash

echo "🔍 Search for subscriptions available..."
subscriptions=$(az account list --query "[].id" -o tsv)

echo ""
echo "🚀 Starting VM running and vCPUs analysis..."
echo ""

for sub in $subscriptions; do
    az account set --subscription "$sub"
    subName=$(az account show --query "name" -o tsv)

    echo "===================================================================="
    echo "📘 Subscription: $subName ($sub)"
    echo "===================================================================="

    # List VMs
    vms=$(az vm list --show-details --query "[?powerState=='VM running']" -o json)

    vm_count=$(echo "$vms" | jq length)
    echo "🔹 Running VMs: $vm_count"

    total_vcpus=0

    # Cache list-skus for the region (assuming 'eastus' as generic for SKU data)
    sku_data=$(az vm list-skus --resource-type virtualMachines --location eastus -o json)

    # For each running VM, check the vCPUs
    for vm_size in $(echo "$vms" | jq -r '.[].hardwareProfile.vmSize'); do
        # Extract vCPU count from sku capabilities
        vcpu_count=$(echo "$sku_data" | jq "map(select(.name==\"$vm_size\")) | .[0].capabilities[] | select(.name==\"vCPUs\").value" -r)

        # If not found, set to 0
        if [[ -z "$vcpu_count" || "$vcpu_count" == "null" ]]; then
            vcpu_count=0
        fi

        total_vcpus=$((total_vcpus + vcpu_count))
    done

    echo "🔸 vCPUs usage in running VMs: $total_vcpus"
    echo ""
done
