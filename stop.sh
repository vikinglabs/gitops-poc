#!/bin/bash
set -e

# Destroy local environment
kind delete cluster --name local

# Remove old kube config files
