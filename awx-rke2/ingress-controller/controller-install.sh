#!/bin/bash

/usr/local/bin/helm repo add nginx-stable https://helm.nginx.com/stable
/usr/local/bin/helm repo update
/usr/local/bin/helm upgrade --install ingress  nginx-stable/nginx-ingress --set controller.service.type=LoadBalancer --namespace kube-system --cleanup-on-fail
