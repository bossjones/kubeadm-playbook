.PHONY: list help

PR_SHA                := $(shell git rev-parse HEAD)

define ASCILOGO
kubeadm-playbook
=======================================
endef

export ASCILOGO

# http://misc.flogisoft.com/bash/tip_colors_and_formatting

RED=\033[0;31m
GREEN=\033[0;32m
ORNG=\033[38;5;214m
BLUE=\033[38;5;81m
NC=\033[0m

export RED
export GREEN
export NC
export ORNG
export BLUE

# verify that certain variables have been defined off the bat
check_defined = \
    $(foreach 1,$1,$(__check_defined))
__check_defined = \
    $(if $(value $1),, \
      $(error Undefined $1$(if $(value 2), ($(strip $2)))))


export PATH := ./venv/bin:$(PATH)

mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
current_dir := $(notdir $(patsubst %/,%,$(dir $(mkfile_path))))
MAKE := make

list_allowed_args := product ip command role tier

help:
	@printf "\033[1m$$ASCILOGO $$NC\n"
	@printf "\033[21m\n\n"
	@printf "=======================================\n"
	@printf "\n"

list:
	@$(MAKE) -qp | awk -F':' '/^[a-zA-Z0-9][^$#\/\t=]*:([^=]|$$)/ {split($$1,A,/ /);for(i in A)print A[i]}' | sort

download-roles:
	ansible-galaxy install -r requirements.yml --roles-path ./roles/

download-roles-global:
	ansible-galaxy install -r requirements.yml --roles-path=/etc/ansible/roles

download-roles-global-force:
	ansible-galaxy install --force -r requirements.yml --roles-path=/etc/ansible/roles

raw:
	$(call check_defined, product, Please set product)
	$(call check_defined, command, Please set command)
	@ansible localhost -i inventory-$(product)/ ${PROXY_COMMAND} -m raw -a "$(command)" -f 10

# Compile python modules against homebrew openssl. The homebrew version provides a modern alternative to the one that comes packaged with OS X by default.
# OS X's older openssl version will fail against certain python modules, namely "cryptography"
# Taken from this git issue pyca/cryptography#2692
install-virtualenv-osx:
	ARCHFLAGS="-arch x86_64" LDFLAGS="-L/usr/local/opt/openssl/lib" CFLAGS="-I/usr/local/opt/openssl/include" pip install -r requirements.txt

docker-run:
	@virtualization/docker/docker-run.sh

molecule-destroy:
	molecule destroy

install-cidr-brew:
	pip install cidr-brewer

install-test-deps-pre:
	pip install docker-py
	pip install molecule --pre

install-test-deps:
	pip install docker-py
	pip install molecule

ci:
	molecule test

test:
	molecule test --destroy=always

bootstrap:
	echo bootstrap

travis:
	tox

pip-tools-osx:
	ARCHFLAGS="-arch x86_64" LDFLAGS="-L/usr/local/opt/openssl/lib" CFLAGS="-I/usr/local/opt/openssl/include" pip install pip-tools pipdeptree

pip-tools:
	pip install pip-tools pipdeptree

# travis-osx:
# 	$(MAKE) ci

# SOURCE: https://github.com/freedomofpress/ansible-role-jenkins-config/blob/master/requirements.txt
# This file is autogenerated by pip-compile
# To update, run:
#
#    pip-compile --output-file requirements.txt requirements.in
#
.PHONY: pip-compile-upgrade-all
pip-compile-upgrade-all: pip-tools
	pip-compile --output-file requirements.txt requirements.in --upgrade
	pip-compile --output-file requirements-dev.txt requirements-dev.in --upgrade
	pip-compile --output-file requirements-test.txt requirements-test.in --upgrade

.PHONY: pip-compile
pip-compile: pip-tools
	pip-compile --output-file requirements.txt requirements.in
	pip-compile --output-file requirements-dev.txt requirements-dev.in
	pip-compile --output-file requirements-test.txt requirements-test.in

.PHONY: install-deps-all
install-deps-all:
	pip install -r requirements.txt
	pip install -r requirements-dev.txt

provision:
	@bash ./scripts/up.sh
	vagrant sandbox commit
	vagrant reload
	ansible-playbook -i inventory.ini site.yml -v

up:
	@bash ./scripts/up.sh

rollback:
	@bash ./scripts/rollback.sh

commit:
	vagrant sandbox commit

reload:
	@vagrant reload

destroy:
	@vagrant destroy -f

run-ansible:
	@ansible-playbook -i inventory.ini site.yml -v

run-ansible-docker:
	@ansible-playbook -i inventory.ini site.yml -v --tags docker-provision --flush-cache

run-ansible-master:
	@ansible-playbook -i inventory.ini site.yml -v --tags primary_master

run-ansible-timezone:
	@ansible-playbook -i inventory.ini timezone.yml -v

ping:
	@ansible-playbook -v -i inventory.ini ping.yml

# [ANSIBLE0013] Use shell only when shell functionality is required
ansible-lint-role:
	bash -c "find .* -type f -name '*.y*ml' ! -name '*.venv' -print0 | xargs -I FILE -t -0 -n1 ansible-lint -x ANSIBLE0006,ANSIBLE0007,ANSIBLE0010,ANSIBLE0013 FILE"

yamllint-role:
	bash -c "find .* -type f -name '*.y*ml' ! -name '*.venv' -print0 | xargs -I FILE -t -0 -n1 yamllint FILE"

install-ip-cmd-osx:
	brew install iproute2mac

flush-cache:
	@sudo killall -HUP mDNSResponder

bridge-up:
	./vagrant_bridged_demo.sh --full --bridged_adapter auto

bridge-restart:
	./vagrant_bridged_demo.sh --restart

bridge-start:
	./vagrant_bridged_demo.sh --start

ssh-bridge-master:
	ssh -F ./ssh_config boss-master-01.scarlettlab.home

ssh-bridge-worker:
	ssh -F ./ssh_config boss-worker-01.scarlettlab.home

ping-bridge:
	@ansible-playbook -v -i hosts ping.yml

run-bridge-ansible:
	@ansible-playbook -i hosts site.yml -v

run-bridge-test-ansible:
	@ansible-playbook -i hosts test.yml -v

run-bridge-tools-ansible:
	@ansible-playbook -i hosts tools.yml -v

run-bridge-log-iptables-ansible:
	@ansible-playbook -i hosts log_iptables.yml -v

run-bridge-ansible-no-slow:
	@ansible-playbook -i hosts site.yml -v --skip-tags "slow"

run-bridge-debug-ansible:
	@ansible-playbook -i hosts debug.yml -v

dummy-web-server:
	python dummy-web-server.py

busybox-pod:
	kubectl run -it --rm --restart=Never busybox --image=busybox sh

rebuild: destroy flush-cache bridge-up sleep ping-bridge run-bridge-ansible run-bridge-tools-ansible

sleep:
	sleep 300

deploy-rbac:
	kubectl create -f deploy/allow-all-all-rbac.yml

deploy-dashboard-admin:
	kubectl create -f deploy/dashboard-admin.yaml

# nvm-install:
# 	nvm install stable ;
# 	nvm use stable ;
# 	npm install npm@latest -g ;
# 	npm install -g docker-loghose ;
# 	npm install -g docker-enter ;

# hostnames-pod:
# 	kubectl run hostnames --image=k8s.gcr.io/serve_hostname \
# 	--labels=app=hostnames \
#     --port=9376 \
#     --replicas=3 ; \
# 	kubectl get pods -l app=hostnames ; \
# 	kubectl expose deployment hostnames --port=80 --target-port=9376 ; \

pip-install-pygments:
	pip install Pygments

# SOURCE: https://github.com/bossjones/boss-kubernetes-lab/blob/master/charts/helm/Makefile
# kubectl logs -n ingress-nginx nginx-ingress-controller-f88c75bc6-4xkfw
debug-nginx-ingress-resource-events:
	kubectl get ing -n ingress-nginx; \
	kubectl describe ing nginx-welcome -n nginx-welcome; \
	kubectl get pods -n ingress-nginx; \
	echo "Check if used service exists"; \
	kubectl get svc --all-namespaces; \
	kubectl get pods --all-namespaces -l app.kubernetes.io/name=ingress-nginx --watch


####################################################################
# nginx-welcome
####################################################################

# SOURCE: https://docs.bitnami.com/kubernetes/how-to/create-your-first-helm-chart/
helm-deploy-nginx-welcome:
	helm install --wait --debug -n nginx-welcome ./deploy/nginx-welcome; \
	helm ls -a

helm-purge-nginx-welcome:
	helm delete --purge nginx-welcome || (exit 1); \
	helm ls -a

helm-dry-run-nginx-welcome:
	helm install --wait --dry-run --debug -n nginx-welcome ./deploy/nginx-welcome | pygmentize -l yaml

yamllint-nginx-welcome:
	@echo "Running YAML Lint Script:"
	@echo "YAML audit"
	@yamllint --version
	bash -c "find ${PWD}/deploy/nginx-welcome -type f -name '*.y*ml' -print0 | xargs -I FILE -t -0 -n1 yamllint FILE"

lint-nginx-welcome:
	helm lint ./deploy/nginx-welcome

describe-nginx-welcome:
	kubectl describe ing nginx-welcome

dump:
	kubectl cluster-info dump --all-namespaces --output-directory=./dump

dump2:
	kubectl cluster-info dump --all-namespaces --output-directory=./dump2

# https://github.com/kubernetes/dashboard/wiki/Access-control#bearer-token
get-secrets:
	kubectl -n kube-system get secret

list-chart-versions-dashboard:
	helm search stable/kubernetes-dashboard -l

addon-dashboard:
	kubectl apply -f ./addon/dashboard/kubernetes-dashboard.yaml

addon-weave-scope:
	kubectl -n weave apply -f ./addon/weave-scope/scope.yaml

delete-weave-scope:
	kubectl -n weave delete -f ./addon/weave-scope/scope.yaml

debug-weave-scope:
	kubectl -n weave describe deployment weave-scope-app
	kubectl -n weave describe svc weave-scope
	kubectl -n weave describe ds weave-scope-agent


debug-dashboard:
# kubectl -n kube-system describe deployment kubernetes-dashboard
# kubectl -n kube-system describe svc kubernetes-dashboard
# kubectl -n kube-system describe ds kubernetes-dashboard
	 kubectl -n kube-system describe -f addon/dashboard/

# https://github.com/kubernetes/ingress-nginx/blob/master/docs/deploy/baremetal.md
addon-ingress-nginx:
	kubectl apply -f ./addon/ingress-nginx/mandatory.yaml
	kubectl apply -f ./addon/ingress-nginx/service-nodeport.yaml

debug-ingress-nginx:
	kubectl describe -f ./addon/ingress-nginx/

watch-ingress-nginx:
	kubectl get pods --all-namespaces -l app.kubernetes.io/name=ingress-nginx --watch

delete-ingress-nginx:
	kubectl delete -f ./addon/ingress-nginx/mandatory.yaml
	kubectl delete -f ./addon/ingress-nginx/service-nodeport.yaml

# Detect installed version:
# POD_NAME=$(kubectl get pods -l app.kubernetes.io/name=ingress-nginx -o jsonpath='{.items[0].metadata.name}')
# kubectl exec -it $POD_NAME -- /nginx-ingress-controller --version

#  helm install stable/nginx-ingress --name uck-nginx --namespace kube-system --set controller.hostNetwork=true,controller.kind=DaemonSet --set rbac.create=true

addon-heapster:
	kubectl apply -f ./addon/heapster2/

delete-heapster:
	kubectl delete -f ./addon/heapster2/

debug-heapster:
	kubectl describe -f ./addon/heapster2/

debug-heapster-helm:
	echo "heapster must already be deployed on cluster!!"
	helm get manifest heapster
# NOTE:
# NOTE:
# NOTE:
# NOTE:
# NOTE:
# Order of operations
# ansible
# rbac
# dashboard
# weave-scope

# Trying something new
# https://github.com/kubernetes/ingress-nginx/blob/master/docs/deploy/baremetal.md
addon-ingress-nginx2:
	kubectl apply -f ./addon/ingress-nginx2

debug-ingress-nginx2:
	kubectl describe -f ./addon/ingress-nginx2/

watch-ingress-nginx2:
	kubectl get pods --all-namespaces -l app.kubernetes.io/name=ingress-nginx --watch

delete-ingress-nginx2:
	kubectl delete -f ./addon/ingress-nginx2


####################################################
####### addon http-svc
####################################################

addon-http-svc:
	kubectl apply -f ./addon/http-svc

debug-http-svc:
	@echo
	kubectl describe -f ./addon/http-svc/
	@echo
	kubectl get svc http-svc
	@echo

test-http-svc:
	@bash ./scripts/curl-http-svc.sh

delete-http-svc:
	kubectl delete -f ./addon/http-svc

####################################################
####### addon commands
####################################################

# -----------------------------
# DNS -----
# -----------------------------

# ingress.hosts[0]=dashboard.bossk8s.myk8s.corp.bosslab.com,
# ingress.hosts[1]=master-bossk8s.corp.bosslab.com,
# ingress.hosts[2]=boss-master-01.scarlettlab.home

# - { name: prometheus, repo: stable/prometheus-operator, namespace: monitoring, options: '--set prometheus.ingress.enabled=True --set prometheus.ingress.hosts[0]=prometheus.{{ custom.networking.dnsDomain }} --set grafana.ingress.enabled=True --set grafana.ingress.hosts[0]=grafana.{{ custom.networking.dnsDomain }} --set alertmanager.ingress.enabled=True --set alertmanager.ingress.hosts[0]=alertmanager.{{ custom.networking.dnsDomain }}

# - { name: nginx-ingress, repo: stable/nginx-ingress, namespace: kube-system, options: '--set rbac.create=true --set controller.stats.enabled=true --set controller.service.type=NodePort --set controller.service.nodePorts.http=80 --set controller.service.nodePorts.https=443 --version=0.29.1 ' }
# - { name: heapster, repo: stable/heapster, namespace: kube-system, options: '--set service.nameOverride=heapster,rbac.create=true' }

# - { name: dashboard, repo: stable/kubernetes-dashboard, namespace: kube-system, options: '--set rbac.create=True,rbac.clusterAdminRole=True,ingress.enabled=True,ingress.hosts[0]=dashboard.{{ custom.networking.dnsDomain }},ingress.hosts[1]={{ custom.networking.masterha_fqdn | default (groups["primary-master"][0]) }},ingress.hosts[2]={{ groups["primary-master"][0] }},image.tag=v1.10.0 --version=0.5.3' }

# - { name: kured, repo: stable/kured, namespace: kube-system, options: '--set extraArgs.period="0h07m0s"' }


# --------------------------------------------------
# LIST OF SERVICES TO DEPLOY
# --------------------------------------------------
# heapster        1               Wed Dec  5 23:42:42 2018        DEPLOYED        heapster-0.3.2                  1.5.2           kube-system
# kured           1               Wed Dec  5 23:42:46 2018        DEPLOYED        kured-0.1.2                     1.1.0           kube-system
# nginx-ingress   1               Wed Dec  5 23:42:41 2018        DEPLOYED        nginx-ingress-0.29.1            0.20.0          kube-system
# nginx-welcome   1               Thu Dec  6 23:01:12 2018        DEPLOYED        nginx-welcome-0.1.0             1.0             default
# prometheus      1               Wed Dec  5 23:42:51 2018        DEPLOYED        prometheus-operator-0.1.29      0.25.0          monitoring
# weave-scope     1               Thu Dec  6 00:57:55 2018        DEPLOYED        weave-scope-0.10.0              1.9.1           default
