
# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# [START servicemesh_cluster_c_register]
#!/bin/bash
#source env-vars
## TF vars
export PROJECT='${project}'
export LOCATION='${location}'
##

echo "Creating and downloading GKE Hub Service Account"
gcloud iam service-accounts create client-cluster-gke-hub-sa --project=$PROJECT
gcloud projects add-iam-policy-binding $PROJECT \
 --member="serviceAccount:client-cluster-gke-hub-sa@$PROJECT.iam.gserviceaccount.com" \
 --role="roles/gkehub.connect"

echo "Downloading json key to gkehub.json"
gcloud iam service-accounts keys create gkehub.json \
  --iam-account=client-cluster-gke-hub-sa@$PROJECT.iam.gserviceaccount.com \
  --project=$PROJECT
echo "Storing kOps kubeconfig in server-kubeconfig"
./kops export kubecfg server-cluster.k8s.local --kubeconfig $LOCATION/server-kubeconfig --state "gs://$PROJECT-kops-clusters/"/ --admin
echo "Validating cluster - connection errors during validation are expected"
./kops validate cluster server-cluster.k8s.local --state "gs://$PROJECT-kops-clusters"/ --wait 10m --count 1 --kubeconfig $LOCATION/server-kubeconfig
echo "Registering kOps cluster into Anthos in project: $PROJECT"
gcloud container hub memberships register server-cluster \
            --context=server-cluster.k8s.local \
            --service-account-key-file=gkehub.json \
            --kubeconfig=$LOCATION/server-kubeconfig \
            --project=$PROJECT \
            --quiet
echo "Creating login token for CloudConsole (admin account!)"
kubectl --kubeconfig $LOCATION/server-kubeconfig create serviceaccount -n kube-system admin-user
kubectl --kubeconfig $LOCATION/server-kubeconfig create clusterrolebinding admin-user-binding \
  --clusterrole cluster-admin --serviceaccount kube-system:admin-user
SECRET_NAME=$(kubectl --kubeconfig $LOCATION/server-kubeconfig get serviceaccount -n kube-system admin-user \
  -o jsonpath='{$.secrets[0].name}')
echo "Copy this token and use it to login to your cluster in cloud console"
echo $(kubectl --kubeconfig $LOCATION/server-kubeconfig get secret -n kube-system $SECRET_NAME -o jsonpath='{$.data.token}' \
  | base64 -d | sed $'s/$/\\\n/g') >> server-cluster-ksa.token

# [END servicemesh_cluster_c_register]