# Multicloud Kubernetes Modules

Terraform and YAML modules for provisioning Kubernetes clusters across AWS EKS, Azure AKS, Google GKE, and Red Hat OpenShift, including auto-mode capabilities and Karpenter.

## Architecture

| Platform | Auto Mode | Description |
|----------|-----------|-------------|
| **AWS EKS** | [EKS Auto Mode](modules/eks/) | AWS-managed compute, networking, storage, scaling |
| **AWS EKS** | [Karpenter](modules/eks/karpenter/) | Open-source node autoscaling with custom provisioning |
| **Azure AKS** | [AKS Automatic + NAP](modules/aks/) | Automated cluster ops + dynamic node pool creation |
| **Google GKE** | [GKE Autopilot](modules/gke/) | Fully Google-managed nodes and infrastructure |
| **OpenShift** | [Hosted CP + Machine API + CA](modules/openshift/) | Modular control/data plane separation + machine autoscaling |

## Module Capabilities

### AWS EKS (`modules/eks/`)
- **EKS Auto Mode** — AWS fully manages compute, networking, storage, scaling via `compute_config`, `storage_config`, `kubernetes_network_config`
- **Karpenter** — Open-source node autoscaler with `NodePool` and `EC2NodeClass` CRDs, interruption handling via SQS + EventBridge, IRSA-based IAM
- **Managed Node Groups** — Traditional approach with `aws_eks_node_group`
- **Cluster Autoscaler** — Auto-deployed via Helm for the managed node groups path
- **AWS LB Controller** — Proper IRSA role for `aws-load-balancer-controller` (not shared with Karpenter)
- **EKS Addons** — `vpc-cni`, `coredns`, `kube-proxy` by default, extensible via `addons` variable
- **KEDA** — Event-driven autoscaling (optional, with IRSA for AWS integrations)
- **Traefik** — Ingress controller with ACME/LetsEncrypt support (optional)

### Azure AKS (`modules/aks/`)
- **AKS Automatic** — SKU-tier automated cluster with integrated container registry, monitoring, RBAC
- **Node Auto Provisioning (NAP)** — Dynamic node pool creation via `node_provisioning_profile`
- **Karpenter (experimental)** — Helm install with Azure Workload Identity federation

### Google GKE (`modules/gke/`)
- **GKE Autopilot** — Fully managed mode
- **Standard Mode** — Traditional node pools with autoscaling
- **Karpenter (experimental)** — Helm install with GCP service account, `GCENodeClass` CRD

### OpenShift ROSA (`modules/openshift/`)
- **Hosted Control Planes (HyperShift)** — Separate control plane from data plane
- **Machine API** — MachineSet/MachineAutoscaler templates for AWS
- **Cluster Autoscaler** — OpenShift-native CA with `ClusterAutoscaler` CRD
- **Karpenter (experimental)** — Helm install for advanced node provisioning

## Prerequisites

- Terraform >= 1.5
- Providers: AWS (`>= 5.0`), Azure (`>= 4.0`), GCP (`>= 5.0`), Helm (`>= 2.0`), Kubernetes (`>= 2.0`)
- AWS CLI (for EKS/ROSA), Azure CLI (for AKS), Google Cloud SDK (for GKE)
- ROSA CLI + `oc` CLI (for OpenShift)

## Usage

```bash
# EKS with Karpenter
cd examples/eks
terraform init && terraform apply -var-file=terraform.tfvars.example

# AKS with Node Auto Provisioning
cd examples/aks
terraform init && terraform apply -var-file=terraform.tfvars.example

# GKE Autopilot
cd examples/gke
terraform init && terraform apply -var-file=terraform.tfvars.example

# OpenShift ROSA
cd examples/openshift
terraform init && terraform apply -var-file=terraform.tfvars.example
```

## EKS Node Management Modes

| Mode | Compute | Networking | Scaling | Addons |
|------|---------|------------|---------|--------|
| **Auto Mode** | AWS-managed | AWS-managed | Automatic | AWS-managed |
| **Karpenter** | Karpenter-managed EC2 | User-managed | Karpenter (NodePool) | User-managed |
| **Node Groups** | Managed node groups | User-managed | Cluster Autoscaler | User-managed |

## Karpenter Cross-Cloud Support

| Platform | Status | NodeClass CRD | Auth |
|----------|--------|---------------|------|
| **EKS** | Native | `EC2NodeClass` | IRSA (IAM) |
| **AKS** | Experimental | N/A | Workload Identity |
| **GKE** | Experimental | `GCENodeClass` | GCP Service Account |
| **OpenShift** | Experimental | N/A | Service Account |

## Project Structure

```
├── versions.tf                  # Provider version constraints
├── modules/
│   ├── eks/                     # AWS EKS
│   │   ├── main.tf              # Cluster, node groups, auto mode, karpenter CRDs, LB controller, CA
│   │   ├── variables.tf         # Input variables
│   │   ├── outputs.tf           # Outputs
│   │   ├── karpenter/           # Karpenter sub-module (IAM, Helm, SQS, EventBridge)
│   │   │   ├── main.tf
│   │   │   ├── values.yaml
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   └── karpenter-nodepool.yaml  # Reference NodePool/EC2NodeClass examples
│   ├── aks/                     # Azure AKS
│   ├── gke/                     # Google GKE
│   └── openshift/               # Red Hat OpenShift (ROSA)
├── examples/
│   ├── eks/                     # EKS example with VPC
│   ├── aks/                     # AKS example with VNet
│   ├── gke/                     # GKE example
│   └── openshift/               # ROSA example with VPC
└── README.md
```
