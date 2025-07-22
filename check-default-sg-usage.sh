#!/bin/bash

# Regions to check
REGIONS=("us-east-1" "us-east-2" "us-west-1" "us-west-2")

for REGION in "${REGIONS[@]}"; do
  echo -e "\n=============================="
  echo -e "🔍 Checking Region: $REGION"
  echo -e "=============================="

  # Get all default SGs across all VPCs in this region
  DEFAULT_SGS=$(aws ec2 describe-security-groups \
    --region "$REGION" \
    --filters Name=group-name,Values=default \
    --query "SecurityGroups[*].{ID:GroupId,VpcId:VpcId}" \
    --output json)

  COUNT=$(echo "$DEFAULT_SGS" | jq length)
  if [ "$COUNT" -eq 0 ]; then
    echo "⚠️  No default SGs found in $REGION"
    continue
  fi

  for i in $(seq 0 $(($COUNT - 1))); do
    SG_ID=$(echo "$DEFAULT_SGS" | jq -r ".[$i].ID")
    VPC_ID=$(echo "$DEFAULT_SGS" | jq -r ".[$i].VpcId")

    echo -e "\n➡️  VPC: $VPC_ID | Default SG: $SG_ID"

    # Check ENIs
    ENIS=$(aws ec2 describe-network-interfaces \
      --region "$REGION" \
      --filters Name=group-id,Values="$SG_ID" \
      --query "NetworkInterfaces[*].{ID:NetworkInterfaceId,Type:InterfaceType,Desc:Description}" \
      --output json)

    if [ "$(echo "$ENIS" | jq length)" -eq 0 ]; then
      echo "  ✅ ENI: No ENIs use this SG."
    else
      echo "  🚨 ENI: Default SG is used by these ENIs:"
      echo "$ENIS" | jq -c '.[]' | while read -r eni; do
        ENI_ID=$(echo "$eni" | jq -r .ID)
        TYPE=$(echo "$eni" | jq -r .Type)
        DESC=$(echo "$eni" | jq -r .Desc)
        echo "    • ENI ID: $ENI_ID, Type: $TYPE, Desc: $DESC"
      done
    fi

    # Check Lambdas
    LAMBDAS=$(aws lambda list-functions --region "$REGION" --query 'Functions[*].FunctionName' --output text)
    for FUNC in $LAMBDAS; do
      CONFIG=$(aws lambda get-function-configuration --region "$REGION" --function-name "$FUNC" 2>/dev/null)
      if echo "$CONFIG" | jq -r '.VpcConfig.SecurityGroupIds[]?' | grep -q "$SG_ID"; then
        echo "  🚨 Lambda: Function '$FUNC' uses the default SG."
      fi
    done

    # ElastiCache
    CACHE_CLUSTERS=$(aws elasticache describe-cache-clusters \
      --region "$REGION" \
      --query "CacheClusters[*].{ID:CacheClusterId,Sgs:SecurityGroups[*].SecurityGroupId}" \
      --output json)
    echo "$CACHE_CLUSTERS" | jq -c '.[]' | while read -r cluster; do
      CLUSTER_ID=$(echo "$cluster" | jq -r .ID)
      if echo "$cluster" | jq -r '.Sgs[]?' | grep -q "$SG_ID"; then
        echo "  🚨 ElastiCache: Cluster '$CLUSTER_ID' uses the default SG."
      fi
    done

    # Redshift
    REDSHIFT_CLUSTERS=$(aws redshift describe-clusters \
      --region "$REGION" \
      --query "Clusters[*].{ID:ClusterIdentifier,Sgs:VpcSecurityGroups[*].VpcSecurityGroupId}" \
      --output json)
    echo "$REDSHIFT_CLUSTERS" | jq -c '.[]' | while read -r cluster; do
      CLUSTER_ID=$(echo "$cluster" | jq -r .ID)
      if echo "$cluster" | jq -r '.Sgs[]?' | grep -q "$SG_ID"; then
        echo "  🚨 Redshift: Cluster '$CLUSTER_ID' uses the default SG."
      fi
    done

    # RDS
    RDS_INSTANCES=$(aws rds describe-db-instances \
      --region "$REGION" \
      --query "DBInstances[*].{ID:DBInstanceIdentifier,Sgs:VpcSecurityGroups[*].VpcSecurityGroupId}" \
      --output json)
    echo "$RDS_INSTANCES" | jq -c '.[]' | while read -r db; do
      DB_ID=$(echo "$db" | jq -r .ID)
      if echo "$db" | jq -r '.Sgs[]?' | grep -q "$SG_ID"; then
        echo "  🚨 RDS: Instance '$DB_ID' uses the default SG."
      fi
    done

    # Check if other SGs reference this one
    REF_SGS=$(aws ec2 describe-security-group-rules \
      --region "$REGION" \
      --filters Name="referenced-group-id",Values="$SG_ID" \
      --query "SecurityGroupRules[*].GroupId" \
      --output text 2>/dev/null)
    if [ -n "$REF_SGS" ]; then
      echo "  🚨 SG Ref: These SGs reference this default SG: $REF_SGS"
    else
      echo "  ✅ SG Ref: No other SGs reference this default SG."
    fi

  done
done
