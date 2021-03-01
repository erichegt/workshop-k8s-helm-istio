#!/bin/bash

total_number_services=5

function install() {
    if [[ -z "${1}" ]]; then
        rm -rf helm-generated.yaml
        touch helm-generated.yaml
    fi

    [[ $ISTIO_CIRCUIT_BREAKER_ON = 1 ]] && circuitBreaker="true" || circuitBreaker="false"

    cd kube

    for ((i=1;i<=$total_number_services;i++)) do
    if (($i == 1)); then
        if [[ -z "${1}" ]]; then
            helm -n istio-dev upgrade hello-istio${i} . -f values-dev.yaml --set nameOverride=hello-istio${i} --set fullnameOverride=hello-istio${i} --set enableCircuitBreaker=$circuitBreaker --install # --atomic --cleanup-on-fail #para CI/CD ideal é garantir atomicidade, como o apply fica mais lento estou evitando aqui
        else
            helm -n istio-dev template hello-istio${i} . -f values-dev.yaml --set nameOverride=hello-istio${i} --set fullnameOverride=hello-istio${i}  --set enableCircuitBreaker=$circuitBreaker >> ../helm-generated.yaml
        fi
    else
        service_number=$((${i}-1))
        if (($i == $total_number_services)); then
            if [[ -z "${1}" ]]; then
                helm -n istio-dev upgrade hello-istio${i} . -f values-dev.yaml --set nextService=hello-istio${service_number} --set nameOverride=hello-istio${i} --set fullnameOverride=hello-istio${i} --set enableGateway=true --set enableCircuitBreaker=$circuitBreaker  --install # --atomic --cleanup-on-fail
            else
                helm -n istio-dev template hello-istio${i} . -f values-dev.yaml --set nextService=hello-istio${service_number} --set nameOverride=hello-istio${i} --set fullnameOverride=hello-istio${i} --set enableGateway=true  --set enableCircuitBreaker=$circuitBreaker >> ../helm-generated.yaml
            fi
        else
            if [[ -z "${1}" ]]; then
                helm -n istio-dev upgrade hello-istio${i} . -f values-dev.yaml --set nextService=hello-istio${service_number} --set nameOverride=hello-istio${i} --set fullnameOverride=hello-istio${i} --set enableCircuitBreaker=$circuitBreaker --install # --atomic --cleanup-on-fail
            else
                helm -n istio-dev template hello-istio${i} . -f values-dev.yaml --set nextService=hello-istio${service_number} --set nameOverride=hello-istio${i} --set fullnameOverride=hello-istio${i} --set enableCircuitBreaker=$circuitBreaker >> ../helm-generated.yaml
            fi
        fi
    fi
    done
}

function callIngress() {
    curl -i http://localhost:7000 -H "Host: hello-istio-public.aws.my-company.io"
}

function callIngressChain() {
    if [[ -z "${1}" ]]; then
        watch -n1 'curl http://localhost:7000/chain -H "Host: hello-istio-public.aws.my-company.io" | json_pp'
    else
        curl http://localhost:7000/chain -H "Host: hello-istio-public.aws.my-company.io"
    fi
}

function callIngressChainBulk() {
    seq 1 60 | xargs -n1 -P3  curl http://localhost:7000/chain -H "Host: hello-istio-public.aws.my-company.io"
}

function callDelay() {
    curl -i -X POST http://localhost:6000/changeDelay
}

function callCaos() {
    curl -i -X POST http://localhost:6000/changeCaos
}

function deleteResources() {
    for ((i=1;i<=$total_number_services;i++)) do
        helm -n istio-dev delete hello-istio${i}
    done
}

function enableGreen() {
    if [[ -z "${4}" ]]; then
        rm -rf helm-generated.yaml
        touch helm-generated.yaml
    fi

    [[ $ISTIO_CIRCUIT_BREAKER_ON = 1 ]] && circuitBreaker="true" || circuitBreaker="false"

    cd kube

    chosen_app=${1}
    green_version=${2}
    green_percentage=${3}
    service_number=$((${chosen_app}-1))
    if [[ -z "${4}" ]]; then
        helm -n istio-dev upgrade hello-istio${chosen_app} . -f values-dev.yaml --set nextService=hello-istio${service_number} --set nameOverride=hello-istio${chosen_app} --set fullnameOverride=hello-istio${chosen_app} --set greenAppVersion=${green_version} --set greenPercentage=${green_percentage}  --set enableCircuitBreaker=$circuitBreaker  --install # --atomic --cleanup-on-fail
    else
        helm -n istio-dev template hello-istio${chosen_app} . -f values-dev.yaml --set nextService=hello-istio${service_number} --set nameOverride=hello-istio${chosen_app} --set fullnameOverride=hello-istio${chosen_app} --set greenAppVersion=${green_version} --set greenPercentage=${green_percentage}  --set enableCircuitBreaker=$circuitBreaker  --debug >> ../helm-generated.yaml
    fi
}

function portForwardSVC() {
    echo "Port-Forwarding svc #${1}"
    kubectl -n istio-dev port-forward svc/hello-istio$1 6000:80
}

function portForwardIngress() {
    kubectl -n istio-system port-forward svc/istio-ingressgateway 7000:80
}

function openJaeger() {
    istioctl dashboard jaeger
}

function openKiali() {
    istioctl dashboard kiali
}

case "$1" in
    "install")
		install $2
		;;
	"clean")
		deleteResources
		;;
    "pf")
		portForwardSVC $2
		;;
    "enableGreen")
        enableGreen $2 $3 $4 $5
        ;;
    "pfIngress")
		portForwardIngress
		;;
    "enableCB")
		turnOnCircuitBreaker
		;;
	"kiali")
		openKiali
		;;
    "jaeger")
		openJaeger
		;;
	"call")
		callIngress
		;;
    "callDelay")
		callDelay
		;;
    "callCaos")
		callCaos
		;;
	"callChain")
		callIngressChain $2
		;;
    "callChainBulk")
		callIngressChainBulk
		;;
	*)
		error "Usage: $0 clean|install|pf|pfIngress|call|callDelay|callChain|callChainBulk|enableGreen|kiali|jaeger"
		exit 1
		;;
esac
