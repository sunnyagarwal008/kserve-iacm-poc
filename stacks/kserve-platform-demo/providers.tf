# IaCM runs this stack with KubernetesDirect and mounts the pod's service
# account token. Null Kubernetes settings let client-go select in-cluster auth.
provider "helm" {
  kubernetes {
    host                   = null
    token                  = null
    cluster_ca_certificate = null
  }
}
