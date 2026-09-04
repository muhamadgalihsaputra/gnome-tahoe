#!/bin/bash

COMPARTMENT_ID="ocid1.tenancy.oc1..aaaaaaaa37l67qkhblzf2glbzuatnxyvieb4xgkmctamplrt7g7cbzwoow5q"
SUBNET_ID="ocid1.subnet.oc1.ap-batam-1.aaaaaaaalxrhstdw3zknoweqyeg5trkyl7hbumviy2647ya5c7gkvmgjwvgq"
IMAGE_ID="ocid1.image.oc1.ap-batam-1.aaaaaaaa3iz7x5zuxgl26l4xcpvf4qmwsq5rbujaonjgfvg3ou7kt5ix2zvq"
SSH_KEY=$(cat ~/.ssh/id_rsa.pub)

while true; do
  echo "[$(date '+%H:%M:%S')] Trying to create instance..."
  
  result=$(oci compute instance launch \
    --availability-domain "aPBI:AP-BATAM-1-AD-1" \
    --compartment-id "$COMPARTMENT_ID" \
    --shape "VM.Standard.A1.Flex" \
    --shape-config '{"ocpus":2,"memoryInGBs":12}' \
    --image-id "$IMAGE_ID" \
    --subnet-id "$SUBNET_ID" \
    --assign-public-ip true \
    --ssh-authorized-keys-file ~/.ssh/id_rsa.pub \
    --boot-volume-size-in-gbs 200 \
    --display-name "galyarder-server" \
    2>&1)

  if echo "$result" | grep -q '"lifecycle-state"'; then
    echo "✅ Instance created!"
    echo "$result" | grep -E '"id"|"lifecycle-state"|"public-ip"'
    break
  else
    echo "$result"
    if [ "${OCI_ONCE:-0}" = "1" ]; then
      echo "❌ Failed. Exiting after one attempt because OCI_ONCE=1."
      exit 1
    fi
    echo "❌ Failed, retry in 5 min..."
    sleep 300
  fi
done
