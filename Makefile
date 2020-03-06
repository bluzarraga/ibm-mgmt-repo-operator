# Copyright 2020 IBM Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Default goal
.DEFAULT_GOAL:=help

# This repo is build locally for dev/test by default;
# Override this variable in CI env.
BUILD_LOCALLY ?= 1

# The namespace that the test operator will be deployed in
NAMESPACE=ibm-mgmt-repo-operator

# Image URL to use all building/pushing image targets;
# Use your own docker registry and image name for dev/test by overridding the IMG and REGISTRY environment variable.
IMG ?= ibm-mgmt-repo-operator
REGISTRY ?= quay.io/opencloudio
CSV_VERSION ?= 0.0.1

QUAY_USERNAME ?=
QUAY_PASSWORD ?=

# Github host to use for checking the source tree;
# Override this variable ue with your own value if you're working on forked repo.
GIT_HOST ?= github.com/IBM

BASE_DIR := ibm-mgmt-repo-operator

TESTARGS_DEFAULT := "-v"
export TESTARGS ?= $(TESTARGS_DEFAULT)
DEST := $(GIT_HOST)/$(BASE_DIR)
VERSION ?= $(shell git describe --exact-match 2> /dev/null || \
                 git describe --match=$(git rev-parse --short=8 HEAD) --always --dirty --abbrev=8)

LOCAL_OS := $(shell uname)
LOCAL_ARCH := $(shell uname -m)
ifeq ($(LOCAL_OS),Linux)
    TARGET_OS ?= linux
    XARGS_FLAGS="-r"
	STRIP_FLAGS=
else ifeq ($(LOCAL_OS),Darwin)
    TARGET_OS ?= darwin
    XARGS_FLAGS=
	STRIP_FLAGS="-x"
else
    $(error "This system's OS $(LOCAL_OS) isn't recognized/supported")
endif

all: check test build images


include commonUtil/Makefile.common.mk


############################################################
# check section
############################################################

check: lint ## Check all files lint error

# All available linters: lint-dockerfiles lint-scripts lint-yaml lint-copyright-banner lint-go lint-python lint-helm lint-markdown lint-sass lint-typescript lint-protos
# Default value will run all linters, override these make target with your requirements:
#    eg: lint: lint-go lint-yaml
lint: lint-all

############################################################
# csv section
############################################################

generate-csv: ## Generate CSV
	- operator-sdk generate csv --csv-version $(CSV_VERSION)
	- cp deploy/crds/*_crd.yaml deploy/olm-catalog/$(BASE_DIR)/$(CSV_VERSION)/

push-csv: ## Push CSV package to the catalog
	@RELEASE=${CSV_VERSION} commonUtil/scripts/push-csv.sh

############################################################
# test section
############################################################

test: test-e2e ## Run integration e2e tests with different options

test-e2e: 
	@echo ... Running the same e2e tests with different args ...
	@echo ... Running locally ...
	- operator-sdk test local ./test/e2e --verbose --up-local --namespace=${NAMESPACE}
	# @echo ... Running with the param ...
	# - operator-sdk test local ./test/e2e --namespace=${NAMESPACE}

scorecard: ## Run scorecard test
	@echo ... Running the scorecard test
	- operator-sdk scorecard --verbose

############################################################
# images section
############################################################

ifeq ($(BUILD_LOCALLY),0)
    export CONFIG_DOCKER_TARGET = config-docker
config-docker:
endif

build: install-operator-sdk $(CONFIG_DOCKER_TARGET) build-amd64 build-ppc64le build-s390x ## Build multi-arch operator images

build-amd64:
	$(eval ARCH := $(shell uname -m|sed 's/x86_64/amd64/'))
	@echo "Building the ${IMG} amd64 binary..."
	@operator-sdk build --image-build-args "-f build/Dockerfile" $(REGISTRY)/$(IMG)-amd64:$(VERSION)

build-ppc64le:
	@echo "Building the ${IMG} ppc64le binary..."
	@operator-sdk build --image-build-args "-f build/Dockerfile.ppc64le" $(REGISTRY)/$(IMG)-ppc64le:$(VERSION)

build-s390x:
	@echo "Building the ${IMG} s390x binary..."
	@operator-sdk build --image-build-args "-f build/Dockerfile.s390x" $(REGISTRY)/$(IMG)-s390x:$(VERSION)

############################################################
# Image section
############################################################

images: clean build push ## Release multi-arch operator image

push: push-amd64 push-ppc64le push-s390x push-multi-arch

push-amd64:
	docker push $(REGISTRY)/$(IMG)-amd64:$(VERSION)

push-ppc64le:
	docker push $(REGISTRY)/$(IMG)-ppc64le:$(VERSION)

push-s390x:
	docker push $(REGISTRY)/$(IMG)-s390x:$(VERSION)

push-multi-arch:
ifeq ($(TARGET_OS),$(filter $(TARGET_OS),linux darwin))
	@curl -L -o /tmp/manifest-tool https://github.com/estesp/manifest-tool/releases/download/v1.0.0/manifest-tool-$(TARGET_OS)-amd64
	@chmod +x /tmp/manifest-tool
	@echo "Merging and push multi-arch image $(REGISTRY)/$(IMG):latest"
	@/tmp/manifest-tool --username $(QUAY_USERNAME) --password $(QUAY_PASSWORD) push from-args --platforms linux/amd64,linux/ppc64le,linux/s390x --template $(REGISTRY)/$(IMG)-ARCH:$(VERSION) --target $(REGISTRY)/$(IMG):latest --ignore-missing
	@echo "Merging and push multi-arch image $(REGISTRY)/$(IMG):v$(CSV_VERSION)"
	@/tmp/manifest-tool --username $(QUAY_USERNAME) --password $(QUAY_PASSWORD) push from-args --platforms linux/amd64,linux/ppc64le,linux/s390x --template $(REGISTRY)/$(IMG)-ARCH:$(VERSION) --target $(REGISTRY)/$(IMG):v$(CSV_VERSION) --ignore-missing
endif

############################################################
# application section
############################################################

install: ## Install all resources (CR/CRD's, RBCA and Operator)
	@echo ....... Set environment variables ......
	- export DEPLOY_DIR=deploy/crds
	- export WATCH_NAMESPACE=${NAMESPACE}
	@echo ....... Creating namespace .......
	- kubectl create namespace ${NAMESPACE}
	@echo ....... Applying CRDS and Operator .......
	- for crd in $(ls deploy/crds/*_crd.yaml); do echo kubectl apply -f ${crd}; done
	@echo ....... Applying RBAC .......
	- kubectl apply -f deploy/service_account.yaml -n ${NAMESPACE}
	- kubectl apply -f deploy/role.yaml -n ${NAMESPACE}
	- kubectl apply -f deploy/role_binding.yaml -n ${NAMESPACE}
	@echo ....... Applying Operator .......
	- kubectl apply -f deploy/operator.yaml -n ${NAMESPACE}
	@echo ....... Creating the Instance .......
	- kubectl apply -f deploy/crds/operator.ibm.com_v1alpha1_*_cr.yaml -n ${NAMESPACE}

uninstall: ## Uninstall all that all performed in the $ make install
	@echo ....... Uninstalling .......
	@echo ....... Deleting CR .......
	- kubectl delete -f deploy/crds/operator.ibm.com_v1alpha1_*_cr.yaml -n ${NAMESPACE}
	@echo ....... Deleting Operator .......
	- kubectl delete -f deploy/operator.yaml -n ${NAMESPACE}
	@echo ....... Deleting CRDs.......
	- for crd in $(ls deploy/crds/*_crd.yaml); do echo kubectl delete -f ${crd}; done
	@echo ....... Deleting Rules and Service Account .......
	- kubectl delete -f deploy/role_binding.yaml -n ${NAMESPACE}
	- kubectl delete -f deploy/service_account.yaml -n ${NAMESPACE}
	- kubectl delete -f deploy/role.yaml -n ${NAMESPACE}
	@echo ....... Deleting namespace ${NAMESPACE}.......
	- kubectl delete namespace ${NAMESPACE}

############################################################
# operator source section
############################################################
operatorsource: ## Create opencloud-operators operator source
	- kubectl delete -f commonUtil/resources/opencloud-operators.yaml
	- kubectl apply -f commonUtil/resources/opencloud-operators.yaml

############################################################
# clean section
############################################################
clean: ## Clean build binary
	@docker images | grep "${REGISTRY}/${IMG}" | tr -s ' ' | awk -F' ' '{print $$1 ":" $$2;}' | xargs -I {}  docker rmi {}
	@rm -f build/_output/bin/$(IMG)

############################################################
# help section
############################################################
help: ## Display this help
	@echo "Usage:\n  make \033[36m<target>\033[0m"
	@awk 'BEGIN {FS = ":.*##"}; \
		/^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } \
		/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: all build check lint test images