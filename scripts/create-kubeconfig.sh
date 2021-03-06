#!/bin/bash

set -euo pipefail

declare MINIKUBE_HOST=${1:-192.168.86.48}

# private key to be used to authenticate with MINIKUBE_HOST for USER
declare KEYFILE_PATH=${2:-${HOME}/.ssh/emu-fedora}

# user on the minikube host
declare USER=${3:-mwh}

declare MINIKUBE_PROFILE_NAME=${4:-minikube}

# as the remote server, assume we want the kubeconfig at the exported KUBECONFIG location
declare REMOTE_KUBECONFIG_PATH=${KUBECONFIG}
declare CERTS_DIR="$DEMO_HOME/$CONFIG_SUBDIR/certs"


if [[ -f $REMOTE_KUBECONFIG_PATH ]]; then
    echo "Removing old config file at ${REMOTE_KUBECONFIG_PATH}"
    rm ${REMOTE_KUBECONFIG_PATH}
fi

if [[ ! -d ${CERTS_DIR} ]]; then
    echo "Creating certs dir ${CERTS_DIR}"
    mkdir -p ${CERTS_DIR}
fi

# Assume this is run right after minikube is setup on host machine for user ${USER}
if [[ $MINIKUBE_HOST == "localhost" ]]; then
    cp ~/.kube/config ${REMOTE_KUBECONFIG_PATH}
else
    scp -i ${KEYFILE_PATH} ${USER}@${MINIKUBE_HOST}:~/.kube/config ${REMOTE_KUBECONFIG_PATH}
fi

# find the host directory for certs.  For kubectl config documentation and examples, see
# this site: https://kubernetes.io/docs/reference/kubectl/cheatsheet/#kubectl-context-and-configuration
CA_CRT=$(kubectl config view -o jsonpath="{.clusters[?(@.name == \"${MINIKUBE_PROFILE_NAME}\")].cluster.certificate-authority}" --kubeconfig=${REMOTE_KUBECONFIG_PATH})
kubectl config set clusters.${MINIKUBE_PROFILE_NAME}.certificate-authority "${CERTS_DIR}/$(basename ${CA_CRT})" --kubeconfig=${REMOTE_KUBECONFIG_PATH}
CLIENT_CRT=$(kubectl config view -o jsonpath="{.users[?(@.name == \"${MINIKUBE_PROFILE_NAME}\")].user.client-certificate}" --kubeconfig=${REMOTE_KUBECONFIG_PATH})
kubectl config set users.${MINIKUBE_PROFILE_NAME}.client-certificate "${CERTS_DIR}/$(basename ${CLIENT_CRT})" --kubeconfig=${REMOTE_KUBECONFIG_PATH}
CLIENT_KEY=$(kubectl config view -o jsonpath="{.users[?(@.name == \"${MINIKUBE_PROFILE_NAME}\")].user.client-key}" --kubeconfig=${REMOTE_KUBECONFIG_PATH})
kubectl config set users.${MINIKUBE_PROFILE_NAME}.client-key "${CERTS_DIR}/$(basename ${CLIENT_KEY})" --kubeconfig=${REMOTE_KUBECONFIG_PATH}

declare FILES=( ${CA_CRT} ${CLIENT_CRT} ${CLIENT_KEY} )
for HOST_FILE_PATH in ${FILES[@]}; do
    FILE_NAME=$(basename ${HOST_FILE_PATH})
    REMOTE_CERT_FILE_PATH="${CERTS_DIR}/${FILE_NAME}"
    
    if [[ $MINIKUBE_HOST == "localhost" ]]; then
        LOCAL_CERT_FILE_PATH=~/.minikube/profiles/${MINIKUBE_PROFILE_NAME}/${FILE_NAME}
        if [[ ! -f "$LOCAL_CERT_FILE_PATH" ]]; then
            LOCAL_CERT_FILE_PATH=~/.minikube/${FILE_NAME}
        fi       
        
        echo "Copying ${FILE_NAME} from ${LOCAL_CERT_FILE_PATH} to ${REMOTE_CERT_FILE_PATH}."
    
        cp "${LOCAL_CERT_FILE_PATH}" "${REMOTE_CERT_FILE_PATH}"
    else
        echo "Copying ${FILE_NAME} from ${MINIKUBE_HOST}:${HOST_FILE_PATH} to ${REMOTE_CERT_FILE_PATH}."

        scp -i ${KEYFILE_PATH} ${USER}@${MINIKUBE_HOST}:${HOST_FILE_PATH} ${REMOTE_CERT_FILE_PATH}
    fi
    
done



# Reset the server on the config to the current host
if [[ ${MINIKUBE_HOST} != "localhost" ]]; then
    kubectl config set clusters.${MINIKUBE_PROFILE_NAME}.server "https://${MINIKUBE_HOST}:8443" --kubeconfig=${REMOTE_KUBECONFIG_PATH}  
fi