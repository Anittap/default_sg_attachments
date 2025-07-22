# 🔍 AWS Default Security Group Usage Checker

This script audits the usage of **default security groups (SGs)** in specified AWS regions. It helps identify where the default SGs are attached, including:

- ENIs (Elastic Network Interfaces)
- Lambda functions
- ElastiCache clusters
- Redshift clusters
- RDS instances
- Other Security Groups referencing the default SG

---

## 📂 File
**`check-default-sg-usage.sh`**

---

## 🚀 Features

- Iterates through a list of AWS regions.
- Identifies all **default** security groups in each VPC.
- For each default SG:
  - Checks if it is associated with any ENIs.
  - Scans for usage in Lambda functions.
  - Detects ElastiCache clusters using it.
  - Detects Redshift clusters using it.
  - Checks RDS instances for references.
  - Lists other security groups that reference the default SG.

---

## 📦 Prerequisites

- **AWS CLI** installed and configured (`aws configure`)
- **`jq`** installed for JSON parsing
- IAM permissions to:
  - Describe security groups and rules
  - Describe network interfaces
  - List and get Lambda function configurations
  - Describe ElastiCache, RDS, and Redshift clusters

---

## 🛠️ Usage

```bash
chmod +x check-default-sg-usage.sh
./check-default-sg-usage.sh
```

---

## 🌍 Regions Checked

You can customize the regions in the script:

```bash
REGIONS=("us-east-1" "us-east-2" "us-west-1" "us-west-2")
```

---

## 📝 Output

The script provides an organized, readable output, including:

- ✅ Items that do **not** use the default SG
- 🚨 Warnings for items **using** the default SG
- ⚠️ Notification when no default SG is found in a region

Example:

```bash
➡️  VPC: vpc-123456 | Default SG: sg-abcde123
  🚨 ENI: Default SG is used by these ENIs:
    • ENI ID: eni-0a1b2c3d4e, Type: interface, Desc: Primary network interface
  ✅ SG Ref: No other SGs reference this default SG.
```

---

## 📌 Notes

- Default security groups should ideally be unused in production environments.
- This script can help identify compliance gaps or opportunities to enhance your AWS security posture.
- No changes are made by the script—**read-only audit**.

---
